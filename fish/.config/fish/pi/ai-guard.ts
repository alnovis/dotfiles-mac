/**
 * ai-guard — a pi extension for the toolkit's unattended read-only runs (ai review --agentic,
 * verify), loaded by _ai_agent_pi with -e. Not for interactive sessions: a person watches those.
 *
 * - Paths: read / grep / find / ls see only the repository under review (the working
 *   directory, or AI_GUARD_ROOT). The tools take any path, and on the eval a review read a
 *   sibling checkout holding the fix (../s1) and grepped all of ~/work for its rules file. A
 *   path outside is refused with the reason, so the model learns it and goes on.
 * - Context: once a turn has used AI_GUARD_CONTEXT_BUDGET percent (default 75) of the model's
 *   window, AI_GUARD_WINDOW tokens (from pi's config), the same switch to answering: the rest
 *   is the answer's. Past the window the start of the conversation is cut, the rules and the
 *   diff with it. One rule for every model: a fast MoE reading small files gets many turns, a
 *   model reading big ones stops sooner. No window given: off.
 * - Turns: after AI_GUARD_MAX_TURNS turns (default 60, a backstop against a loop now that the
 *   context leads) every tool call is refused and the model
 *   is told to answer from what it has read. A bare cap (the old native loop) ended a wandering
 *   run with no answer at all; here the last turns go to the answer. Still no answer a few
 *   turns later: the run is aborted. The tools stay in the request, refused, not removed: their
 *   definitions open the prompt, and removing them changed its start, so a local model lost its
 *   whole prompt cache and read ~60k tokens again (10 min) before the answer it was asked for.
 * - Read first: a first turn that ends in an answer with no tool call is not taken, once: the
 *   model is told to read the changed files, their callers and tests, and goes on. gemma4,
 *   gpt-oss and qwen3.6 reviewed the diff alone though the skill asks for that reading.
 *   AI_GUARD_REQUIRE_READ=0 turns it off.
 * - Time: after AI_GUARD_TIMEOUT seconds (default 900) the same switch to answering; then the
 *   run is aborted once the model has been silent (no reasoning, no answer streamed) for the
 *   grace, AI_GUARD_GRACE seconds (default half the budget, at least 180). A provider that
 *   hangs (an ollama runner stuck in "Stopping...") kept pi waiting for an answer that never
 *   came, and the whole eval with it. A fixed 180 s after the budget killed a local 27B model
 *   that still had to read the whole conversation again and write its review at ~20 tok/s.
 *   At the budget plus twice the grace (twice the budget by default) the run is aborted
 *   whatever it does: the ceiling, so a run never goes on without end.
 *   Each switch and the abort are told on stderr ("ai-guard: …", with the second it came),
 *   which the toolkit shows under the run line and gives as the reason of an empty answer:
 *   granite's run ended at 1436 s, not at 1080, and its log could not say why. Still
 *   running 30 s after the abort: pi is ended.
 * - Pulse: with AI_GUARD_PULSE (a file), how much of the current answer has streamed, as
 *   "THINKING TEXT" (characters of reasoning, then of the answer), written at most once a
 *   second. pi writes the session file only when an answer is whole, so a model writing one
 *   long answer looked like a provider gone quiet ("no answer for 6m"). The two apart tell
 *   the live line whether the model still thinks or already writes.
 * AI_GUARD_MAX_TURNS=0 / AI_GUARD_TIMEOUT=0 turn that limit off.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { realpathSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, resolve, sep } from "node:path";

const FILE_TOOLS = new Set(["read", "grep", "find", "ls"]);
// Turns allowed after the budget is spent before the run is aborted
const GRACE_TURNS = 3;
// Silence after the time budget before the run is aborted, at least
const MIN_GRACE_S = 180;
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
	// The context budget leads: tool calls are refused once the context fills this share of
	// the model's window, the rest left for the answer. The turns are a backstop against a
	// loop, high enough not to cut a run that fits (laguna was cut at 30 turns while it still
	// read). No window given: the context budget is off.
	const maxTurns = Number(process.env.AI_GUARD_MAX_TURNS ?? 60);
	const timeoutS = Number(process.env.AI_GUARD_TIMEOUT ?? 900);
	const windowTokens = Number(process.env.AI_GUARD_WINDOW ?? 0);
	const contextBudget = Number(process.env.AI_GUARD_CONTEXT_BUDGET ?? 75);
	// A first answer with no tool call is sent back once to read the repository; 0 turns it off
	const requireRead = process.env.AI_GUARD_REQUIRE_READ !== "0";
	let nudged = false;
	const graceS = Number(process.env.AI_GUARD_GRACE ?? Math.max(MIN_GRACE_S, timeoutS / 2));
	const pulse = process.env.AI_GUARD_PULSE ?? "";
	// When the model last streamed anything, reasoning or answer
	let streamedAt = 0;
	let root = process.env.AI_GUARD_ROOT ?? "";
	let spent = "";
	let turnsAfter = 0;
	let aborted = false;
	// Characters of the current answer: its reasoning, and its text
	let thought = 0;
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
		note(`${why} at ${elapsed()}s: tool calls refused, the model is told to answer`);
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
			// Aborted after graceS of silence past the budget, not at a fixed time: a model
			// still streaming its answer is working, not hung
			const budgetAt = t0 + timeoutS * 1000;
			const check = () => {
				const silentS = (Date.now() - Math.max(streamedAt, budgetAt)) / 1000;
				if (silentS >= graceS) {
					abort(ctx, `nothing streamed for ${graceS}s after the time budget (${timeoutS}s)`);
				} else {
					later(graceS - silentS, check);
				}
			};
			later(timeoutS + graceS, check);
			// A ceiling the run never passes, streaming or not: a model that keeps writing turn
			// after turn could otherwise run three more turns of up to max_tokens each, an hour
			// on a local model, with the budget long spent
			const ceilingS = timeoutS + 2 * graceS;
			later(ceilingS, () =>
				abort(ctx, `the run reached its ceiling (${ceilingS}s: the time budget and twice the grace)`),
			);
		}
	});

	pi.on("message_start", (event) => {
		if (event.message.role === "assistant") {
			thought = 0;
			streamed = 0;
		}
	});

	pi.on("message_update", (event) => {
		const e = event.assistantMessageEvent;
		if ("delta" in e && typeof e.delta === "string") {
			if (e.type === "thinking_delta") thought += e.delta.length;
			else streamed += e.delta.length;
		}
		const now = Date.now();
		streamedAt = now;
		if (!pulse || now - pulsedAt < 1000) return;
		pulsedAt = now;
		try {
			writeFileSync(pulse, `${thought} ${streamed}\n`);
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
		// The context this turn used: the prompt it was sent (cached or not) and its answer; the
		// tool results it asked for come on top in the next turn, inside the budget's headroom
		const u = (event as { message?: { usage?: Record<string, number> } }).message?.usage;
		if (!spent && windowTokens > 0 && contextBudget > 0 && u) {
			const used = (u.input ?? 0) + (u.cacheRead ?? 0) + (u.cacheWrite ?? 0) + (u.output ?? 0);
			if (used >= (windowTokens * contextBudget) / 100) {
				spend(`the context budget (${contextBudget}% of ${windowTokens} tokens) is spent with ${used}`);
			}
		}
		if (!spent && maxTurns > 0 && event.turnIndex + 1 >= maxTurns) spend(`the turn budget (${maxTurns}) is spent`);
		// An answer on the first turn with no tool call at all: the model reviewed the diff
		// alone, though the skill asks it to read the files, the callers and the tests (gemma4,
		// gpt-oss and qwen3.6 did, laguna read). Not taken, once: it is told to read first.
		const e = event as { toolResults?: unknown[]; outcome?: string };
		if (!spent && requireRead && !nudged && event.turnIndex === 0 && e.outcome === "completed" && (e.toolResults?.length ?? 0) === 0) {
			nudged = true;
			note(`no tool call in the first turn at ${elapsed()}s: the answer is not taken, the model is told to read the repository first`);
			return {
				entries: [
					{
						type: "custom_message",
						customType: "ai-guard",
						content:
							"You answered without reading the repository. Before you answer, read the changed files in full, and grep for the callers and the tests of the functions they change. Then write the review again, in the format the rules ask for.",
						display: false,
					},
				],
				continue: true,
			};
		}
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
					content: `${spent}. No more tool calls: any call is refused. Write the final answer now, in the format the rules ask for, from what you have already read.`,
					display: false,
				},
			],
		};
	});
}
