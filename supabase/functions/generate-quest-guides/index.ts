Deno.serve(async (req) => {
  const { quest } = await req.json();
  const title = quest?.title ?? "Untitled Quest";

  const guideTypes = [
    "route",
    "knowledge",
    "training",
    "community",
    "resource",
    "opportunity",
  ];

  const guides = guideTypes.map((guideType) => ({
    guide_type: guideType,
    title: `${title}: ${guideType} guide`,
    description: `A ${guideType} guide to help progress "${title}".`,
    suggested_actions: [
      `Clarify the next ${guideType} step`,
      "Pick one action for today",
      "Review progress with Arc",
    ],
  }));

  return Response.json({ guides });
});
