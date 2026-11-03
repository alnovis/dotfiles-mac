// ai-guard (fish/.config/fish/pi/ai-guard.ts) against a stand-in for pi: no model, no pi.
// Usage: node pi-guard.test.mjs EXTENSION REPO_DIR — prints one line per check (a golden).
import { realpathSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// REPO_DIR holds src/a.scala and link-out, a symlink to a directory outside it
const [extension, repo] = process.argv.slice(2);
const realRepo = realpathSync(repo);
const { default: aiGuard } = await import(extension);

// What the extension registers and calls; handlers by event name
function standIn() {
	const handlers = {};
	const pi = {
		active: ["read", "grep", "find", "ls"],
		on(name, fn) {
			(handlers[name] ??= []).push(fn);
		},
		setActiveTools(tools) {
			this.active = tools;
		},
	};
	const ctx = { cwd: repo, aborted: false, abort() { this.aborted = true; } };
	const emit = async (name, event) => {
		let result;
		for (const fn of handlers[name] ?? []) result = await fn({ type: name, ...event }, ctx);
		return result;
	};
	return { pi, ctx, emit };
}

function load(env) {
	for (const k of ["AI_GUARD_MAX_TURNS", "AI_GUARD_TIMEOUT", "AI_GUARD_ROOT"]) delete process.env[k];
	Object.assign(process.env, env);
	const s = standIn();
	aiGuard(s.pi);
	return s;
}

const verdict = (r) => (r?.block ? `blocked: ${r.reason.replaceAll(realRepo, "REPO").replaceAll(homedir(), "~")}` : "allowed");

console.log("== paths");
{
	const { emit } = load({ AI_GUARD_TIMEOUT: "0" });
	await emit("session_start", {});
	const calls = [
		["read", { path: "src/a.scala" }],
		["read", { path: join(repo, "src/a.scala") }],
		["grep", { pattern: "RouteStage" }],
		["find", { pattern: "**/Graph.scala" }],
		["read", { path: "../s1/server/RouteStage.scala" }],
		["read", { path: "/etc/hosts" }],
		["grep", { pattern: "meta-verify", path: "~/work" }],
		["find", { pattern: "/Users/someone/**/cases.md" }],
		["ls", { path: "link-out" }],
		["bash", { command: "git log" }],
	];
	for (const [tool, input] of calls) {
		const shown = JSON.stringify(input).replaceAll(repo, "REPO");
		console.log(`${tool} ${shown} -> ${verdict(await emit("tool_call", { toolName: tool, input }))}`);
	}
}

console.log("== turn budget 3");
{
	const { pi, ctx, emit } = load({ AI_GUARD_MAX_TURNS: "3", AI_GUARD_TIMEOUT: "0" });
	await emit("session_start", {});
	for (let i = 0; i < 7; i++) {
		const r = await emit("turn_end", { turnIndex: i });
		const told = r?.entries?.[0]?.content ? `told: ${r.entries[0].content}` : "-";
		console.log(`turn ${i + 1}: tools [${pi.active}] ${told}${ctx.aborted ? " ABORTED" : ""}`);
		if (i === 2) console.log(`  a call after it -> ${verdict(await emit("tool_call", { toolName: "read", input: { path: "src/a.scala" } }))}`);
		if (ctx.aborted) break;
	}
}

console.log("== time budget");
{
	const { pi, emit } = load({ AI_GUARD_TIMEOUT: "0.05", AI_GUARD_MAX_TURNS: "0" });
	await emit("session_start", {});
	console.log(`before: tools [${pi.active}]`);
	await new Promise((r) => setTimeout(r, 120));
	console.log(`after: tools [${pi.active}]`);
	console.log(`a call -> ${verdict(await emit("tool_call", { toolName: "grep", input: { pattern: "x" } }))}`);
	const r = await emit("turn_end", { turnIndex: 0 });
	console.log(`turn 1: told: ${r?.entries?.[0]?.content}`);
	await emit("session_shutdown", {});
}
