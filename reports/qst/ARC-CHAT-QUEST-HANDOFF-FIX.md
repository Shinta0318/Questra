# Arc Chat to Quest Handoff Fix

## Request
Avoid asking users to re-enter a wish already discussed with Arc.

## Cause
The command-center create action opened the sheet without conversation context.
Quick actions submitted UI command prompts as user wishes; local intent inference
could then turn the generic command into a Quest suggestion.

## Changes
- Prefer the selected suggestion, active clarification session (including answers),
  or pending suggestion when opening Quest creation.
- Recover an actual user wish from recent conversation when no structured suggestion
  is available, and run the existing safety/intent resolution before confirmation.
- Exclude operation prompts and Arc replies from this recovery.
- Route wish/create quick actions into the contextual creation flow.
- Show the inherited wish read-only, with an explicit edit action. Empty conversations
  retain the input form. Editing invalidates the old planning description and preview.
- Preserve user confirmation and existing Quest/Mission persistence behavior.

## Files
- apps/mobile/lib/features/arc/arc_screen.dart
- apps/mobile/lib/features/arc/arc_chat_service.dart
- apps/mobile/lib/features/arc/arc_quick_action.dart
- apps/mobile/lib/features/arc/arc_quest_creation_context.dart
- apps/mobile/test/arc_quest_creation_context_test.dart

## Validation
- Targeted Dart analysis: no issues.
- Flutter tests: 27 passed across arc_quest_creation_context_test,
  arc_chat_service_test, qst_297_arc_clarification_state_machine_test,
  qst_308_arc_draft_integration_test and qst_264_context_navigation_test.
- New Widget test checks conversation -> confirmation -> edit, retaining the wish.
- Local web preview compiled and browser-verified: a Singapore travel wish reaches
  the confirmation sheet without a repeated required textarea.
- Preview uses local mock persistence, not Supabase/Gemini. Live provider and Android
  device validation were not performed. No Quest was saved during browser validation.
- No commit, push, PR, backend or database changes for this fix.
