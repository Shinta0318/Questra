Deno.serve(async (req) => {
  const { guide } = await req.json();
  const guideType = guide?.guide_type ?? "route";

  return Response.json({
    items: [
      {
        title: `${guideType} reference`,
        description: "A neutral external reference to support this guide.",
        url: "https://example.com",
        content_type: "article",
        guide_type: guideType,
        source_type: "star_map",
      },
    ],
  });
});
