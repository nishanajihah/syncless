class DemoPreset {
  const DemoPreset({
    required this.title,
    required this.description,
    required this.content,
  });

  final String title;
  final String description;
  final String content;

  static const List<DemoPreset> presets = [
    DemoPreset(
      title: 'Slack Tech Discussion',
      description: 'Messy engineering thread on Auth redesign & database scaling',
      content: '''
[10:14 AM] alex.pm: hey team, we need to finalize the auth migration before v2.0 launch. Currently users are complaining about session timeouts during long uploads.
[10:16 AM] sarah.dev: Yeah, Supabase JWT refresh token lifetime is set to 3600s, but our mobile app doesn't handle silent refresh when backgrounded.
[10:18 AM] dave.backend: Right. Also we are executing heavy DB queries directly on auth.users which causes connection spikes during peak hours.
[10:21 AM] alex.pm: What's the plan then? Can we move quota tracking out of the main request cycle?
[10:24 AM] dave.backend: I suggest adding PostgreSQL transaction-level locks (pg_advisory_xact_lock) and caching user subscription tier in JWT metadata or Redis. That way we avoid hit on auth.users for every AI call.
[10:28 AM] sarah.dev: Agree. I will also update AuthGate in Flutter to listen to onAuthStateChange stream and auto-refresh sessions before expiring.
[10:32 AM] alex.pm: Perfect. Deadline is Thursday. Sarah handles Flutter AuthGate, Dave handles Supabase RPC locks & RLS policies. Let's aim for staging deploy by Wednesday 4 PM UTC.
''',
    ),
    DemoPreset(
      title: 'Raw Zoom Transcript',
      description: 'Product & AI feature kickoff transcript',
      content: '''
Speaker 1 (Product Lead): Welcome everyone. Today we are scoping out the new document export and history features for Syncless.
Speaker 2 (Senior Engineer): Right now users generate Markdown, but corporate clients need PDF and DOCX exports with custom branding.
Speaker 3 (UX Designer): We should also add a persistent side drawer for saved history so users can retrieve specifications generated last week.
Speaker 1: Great. Let's define the limits. Free users get Markdown export and last 3 generations saved. Pro users get PDF/DOCX export, unlimited history, and priority OpenAI GPT-5.6 processing.
Speaker 2: For PDF rendering on Flutter Web, standard canvas rendering can be slow. We can use client-side print stylesheets or server-side Edge function PDF generation.
Speaker 1: Let's do client-side Markdown to PDF printing for Web first, and file_picker / share_plus for mobile export. Let's make sure zero unauthenticated users can access saved history endpoints.
''',
    ),
    DemoPreset(
      title: 'WhatsApp Client Feedback',
      description: 'Unstructured customer bug reports & feature requests',
      content: '''
Client: Hey team! Loved the early beta demo. But we ran into 2 major issues today during our client meeting.
Support: Thanks for testing! What happened?
Client: First, when pasting a 5,000 word transcript from Otter.ai, the app froze for 3 seconds before showing the generate button.
Client: Second, when the quota was reached, it just said "Error" instead of telling us when our reset time is. We didn't know if it was broken or capped.
Support: Got it. 1) We will add asynchronous web worker parsing & character counter optimization. 2) We will update the error UI to show exact reset countdown like "Quota resets in 3h 15m".
Client: Awesome! Also can you add a button to pre-fill sample chats so our team can test different output types quickly?
''',
    ),
  ];
}
