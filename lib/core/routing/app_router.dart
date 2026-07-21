import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/workspace/presentation/workspace_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'workspace',
      builder: (BuildContext context, GoRouterState state) {
        return const WorkspacePage();
      },
    ),
  ],
  errorBuilder: (BuildContext context, GoRouterState state) {
    return Scaffold(
      body: Center(
        child: Text('This page does not exist: ${state.uri.path}'),
      ),
    );
  },
);
