Deno.serve(async (req) => {
  const { guide } = await req.json();
  const guideType = guide?.guide_type ?? "route";

  return Response.json({
    mission: {
      title: "Complete one beginner-friendly next step",
      description:
        "Spend 5 to 30 minutes today on one concrete action connected to this guide.",
      guide_type: guideType,
      difficulty: "easy",
      status: "todo",
    },
  });
});
