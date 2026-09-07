import 'dart:io';
import 'provider_review_contract.dart';
import 'provider_review_io.dart';

Future<void> main(List<String> arguments) async {
  try {
    String option(String prefix, String fallback) {
      final values = arguments
          .where((value) => value.startsWith(prefix))
          .toList();
      if (values.length > 1)
        throw FormatException('Duplicate review argument.');
      return values.isEmpty ? fallback : values.single.substring(prefix.length);
    }

    final review = JsonMap.from(
      readReviewJson(option('--input=', providerHumanPath)) as Map,
    );
    final checked = await recomputeRecordedReview(
      review,
      resultsPath: option('--results=', providerResultsPath),
    );
    if (canonicalReviewJson(checked) != canonicalReviewJson(review) ||
        checked['passed'] != true) {
      throw StateError(
        'Human review summary does not match case scores, outputs, or corpus coverage.',
      );
    }
    stdout.writeln(
      'Human review outputs, corpus hashes, scores, and coverage verified.',
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
