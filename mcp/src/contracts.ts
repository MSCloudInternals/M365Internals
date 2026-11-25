import { readFileSync } from "node:fs";
import { z } from "zod";

const definition = z.object({
  name: z.string().regex(/^m365_[a-z_]+$/),
  operation: z.string().regex(/^[a-z_]+$/),
  description: z.string(),
  sections: z.record(z.string(), z.string()).optional(),
  path: z.string().optional(),
  domain: z.boolean().optional(),
}).strict();

export const tools = z.array(definition).parse(JSON.parse(
  readFileSync(new URL("../tools.json", import.meta.url), "utf8"),
));

export const domainPattern = /^(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?![\s\S])/;

export function inputSchema(tool: (typeof tools)[number]) {
  if (tool.sections) {
    const names = Object.keys(tool.sections);
    const first = names[0];
    if (!first) throw new Error("Empty MCP section allowlist");
    return z.object({ section: z.enum([first, ...names.slice(1)]) }).strict();
  }
  if (tool.domain) return z.object({ domain: z.string().regex(domainPattern) }).strict();
  return z.object({}).strict();
}

export function validateArguments(operation: string, args: unknown): Record<string, string> {
  const tool = tools.find((item) => item.operation === operation);
  if (!tool) throw new Error("operation_not_allowed");
  const result = inputSchema(tool).safeParse(args);
  if (!result.success) throw new Error("invalid_arguments");
  return result.data;
}

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
const json: z.ZodType<Json> = z.lazy(() => z.union([
  z.null(), z.boolean(), z.number().finite(), z.string().max(500),
  z.array(json).max(50),
  z.record(z.string().max(80), json).refine((value) => Object.keys(value).length <= 50),
]));

export const outputSchema = z.object({
  surface: z.string(),
  section: z.string().nullable(),
  status: z.enum(["ok", "unavailable"]),
  truncated: z.boolean(),
  data: json,
}).strict().superRefine((result, context) => {
  let nodes = 0;
  function walk(value: Json, depth: number): boolean {
    if (++nodes > 2048 || depth > 4) return false;
    if (value !== null && typeof value === "object") {
      return Object.values(value).every((item) => walk(item, depth + 1));
    }
    return true;
  }
  if (!walk(result.data, 0) || (result.status === "unavailable" && result.data !== null)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: "Invalid bounded snapshot" });
  }
});

export const errorCodes = new Set([
  "invalid_request", "invalid_arguments", "operation_not_allowed", "not_connected",
  "not_found", "invalid_response", "upstream_failed", "operation_failed",
  "session_lost", "session_timed_out", "server_busy", "request_cancelled",
]);
