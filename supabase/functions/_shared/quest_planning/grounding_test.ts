import { decideGrounding, sanitizeQueryIntent } from "./grounding.ts";

Deno.test("grounding query intent contains no raw Quest or Success Contract text", () => {
  const input = "山田太郎はシンガポール旅行をしたい。taro@example.com、2027/03/12、予算12万円。";
  const decision = decideGrounding(input);
  if (!decision.required || decision.requiredFacts.length !== 1) {
    throw new Error("Travel Quest must require current official facts");
  }
  const queryIntent = decision.requiredFacts[0].queryIntent;
  for (const privateValue of ["山田太郎", "シンガポール", "taro@example.com", "2027/03/12", "12万円"]) {
    if (queryIntent.includes(privateValue)) {
      throw new Error(`Raw Quest detail appeared in search intent: ${privateValue}`);
    }
  }
  if (!queryIntent.includes("travel") || !queryIntent.toLowerCase().includes("omit names")) {
    throw new Error("Search intent lost its public fact and privacy instructions");
  }
});

Deno.test("grounding remains optional when no current fact is indicated", () => {
  const decision = decideGrounding("毎朝20分走る習慣を3か月続けたい");
  if (decision.required || decision.requiredFacts.length !== 0) {
    throw new Error("A simple habit Quest should not require external search");
  }
  if (sanitizeQueryIntent("資格試験の費用").includes("資格試験の費用")) {
    throw new Error("Search intent must not reproduce user text");
  }
});
