/**
 * ai-guard — a pi extension for the toolkit's unattended read-only runs (ai review --agentic,
 * verify), loaded by _ai_agent_pi with -e. Not for interactive sessions: a person watches those.
 *
 * - Paths: read / grep / find / ls see only the repository under review (the working
 *   directory, or AI_GUARD_ROOT). The tools take any path, and on the eval a review read a
 *   sibling checkout holding the fix (../s1) and grepped all of ~/work for its rules file. A
 *   path outside is refused with the reason, so the model learns it and goes on.
 * - Turns: after AI_GUARD_MAX_TURNS turns (default 30) the tools are switched off and the model
 *   is told to answer from what it has read. A bare cap (the old native loop) ended a wandering
 *   run with no answer at all; here the last turns go to the answer. Still no answer a few
 *   turns later: the run is aborted.
 * - Time: after AI_GUARD_TIMEOUT seconds (default 900) the same switch to answering; 180 s
 *   later the run is aborted. A provider that hangs (an ollama runner stuck in "Stopping…")
 *   kept pi waiting for an answer that never came, and the whole eval with it.
 *   Each switch and the abort are told on stderr ("ai-guard: …", with the second it came),
 *   which the toolkit shows under the run line and gives as the reason of an empty answer:
 *   granite's run ended at 1436 s, not at 1080, and its log could not say why. Still
 *   running 30 s after the abort: pi is ended.
 * - Pulse: with AI_GUARD_PULSE (a file), how much of the current answer has streamed, written
 *   at most once a second. pi writes the session file only when an answer is whole, so a
 *   model writing one long answer looked like a provider gone quiet ("no answer for 6m").
 * AI_GUARD_MAX_TURNS=0 / AI_GUARD_TIMEOUT=0 turn that limit off.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { realpathSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, resolve, sep } from "node:path";

const FILE_TOOLS = new Set(["read", "grep", "find", "ls"]);
// Turns allowed after the budget is spent before the run is aborted
const GRACE_TURNS = 3;
const ABORT_AFTER_TIMEOUT_S = 180;
const EXIT_AFTER_ABORT_S = 30;

// The real path of the longest existing prefix, so a path that does not exist still resolves
// its symlinked parents (/var → /private/var on macOS) and cannot slip out through ".."
function real(path: string): string {
	let cur = path;
	const rest: string[] = [];
	for (;;) {
		try {
			return resolve(realpathSync(cur), ...rest.reverse());
		} catch {
			const parent = dirname(cur);
			if (parent === cur) return path;
			rest.push(cur.slice(parent.length).replace(/^[/\\]+/, ""));
			cur = parent;
		}
	}
}

function expand(path: string): string {
	return path === "~" || path.startsWith("~/") ? homedir() + path.slice(1) : path;
}

// The path a file tool call reaches: its path argument, and for find a pattern that is itself
// an absolute path (up to its first glob character)
function pathsOf(toolName: string, input: Record<string, unknown>): string[] {
	const paths: string[] = [];
	if (typeof input.path === "string" && input.path !== "") paths.push(expand(input.path));
	if (toolName === "find" && typeof input.pattern === "string") {
		const pattern = expand(input.pattern);
		if (isAbsolute(pattern)) paths.push(pattern.split(/[*?[{]/)[0] || "/");
	}
	return paths;
}

export default function aiGuard(pi: ExtensionAPI) {
	const maxTurns = Number(process.env.AI_GUARD_MAX_TURNS ?? 30);
	const timeoutS = Number(process.env.AI_GUARD_TIMEOUT ?? 900);
	const pulse = process.env.AI_GUARD_PULSE ?? "";
	let root = process.env.AI_GUARD_ROOT ?? "";
	let spent = "";
	let turnsAfter = 0;
	let aborted = false;
	let streamed = 0;
	let pulsedAt = 0;
	const t0 = Date.now();
	const timers: ReturnType<typeof setTimeout>[] = [];

	const elapsed = () => Math.round((Date.now() - t0) / 1000);
	const note = (msg: string) => process.stderr.write(`ai-guard: ${msg}\n`);
	const later = (s: number, fn: () => void) => {
		const t = setTimeout(fn, s * 1000);
		t.unref?.();
		timers.push(t);
	};
	const inside = (path: string) => {
		const r = real(resolve(root, path));
		return r === root || r.startsWith(root + sep);
	};
	const spend = (why: string) => {
		if (spent) return;
		spent = why;
		pi.setActiveTools([]);
		note(`${why} at ${elapsed()}s: tools off, the model is told to answer`);
	};
	const abort = (ctx: { abort(): void }, why: string) => {
		if (aborted) return;
		aborted = true;
		note(`aborted at ${elapsed()}s: ${why}`);
		ctx.abort();
		later(EXIT_AFTER_ABORT_S, () => {
			note(`pi still running ${EXIT_AFTER_ABORT_S}s after the abort: ended`);
			process.exit(124);
		});
	};

	pi.on("session_start", (_event, ctx) => {
		root = real(resolve(root || ctx.cwd));
		if (timeoutS > 0) {
			later(timeoutS, () => spend(`the time budget (${timeoutS}s) is spent`));
			later(timeoutS + ABORT_AFTER_TIMEOUT_S, () =>
				abort(ctx, `no answer ${ABORT_AFTER_TIMEOUT_S}s after the time budget (${timeoutS}s)`),
			);
		}
	});

	pi.on("message_start", (event) => {
		if (event.message.role === "assistant") streamed = 0;
	});

	pi.on("message_update", (event) => {
		const e = event.assistantMessageEvent;
		if ("delta" in e && typeof e.delta === "string") streamed += e.delta.length;
		const now = Date.now();
		if (!pulse || now - pulsedAt < 1000) return;
		pulsedAt = now;
		try {
			writeFileSync(pulse, `${streamed}\n`);
		} catch {
			// the dir is gone: the run is ending
		}
	});

	pi.on("session_shutdown", () => {
		for (const t of timers) clearTimeout(t);
	});

	pi.on("tool_call", async (event) => {
		if (spent) {
			return { block: true, reason: `${spent}: no more tools — write the final answer now from what you have read` };
		}
		if (!FILE_TOOLS.has(event.toolName)) return undefined;
		const outside = pathsOf(event.toolName, event.input as Record<string, unknown>).find((p) => !inside(p));
		if (outside !== undefined) {
			return {
				block: true,
				reason: `${outside} is outside the repository under review (${root}): only files inside it may be read`,
			};
		}
		return undefined;
	});

	pi.on("turn_end", async (event, ctx) => {
		if (!spent && maxTurns > 0 && event.turnIndex + 1 >= maxTurns) spend(`the turn budget (${maxTurns}) is spent`);
		if (!spent) return undefined;
		turnsAfter++;
		if (turnsAfter > GRACE_TURNS) {
			abort(ctx, `no answer ${GRACE_TURNS} turns after ${spent}`);
			return undefined;
		}
		if (turnsAfter > 1) return undefined;
		return {
			entries: [
				{
					type: "custom_message",
					customType: "ai-guard",
					content: `${spent}. The tools are switched off: write the final answer now, in the format the rules ask for, from what you have already read.`,
					display: false,
				},
			],
		};
	});
}
