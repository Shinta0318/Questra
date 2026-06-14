Deno.serve(async (req) => {
  const { guide } = await req.json();
  const guideType = guide?.guide_type ?? "route";

  return Response.json({
    advice_text:
      "Take the smallest clear step first. I will keep the path calm, focused, and kind.",
    guide_type: guideType,
    emotion: guideType === "training" ? "support" : "normal",
    source_type: "arc_advice",
  });
});
