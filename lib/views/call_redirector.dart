import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blind_user_app/view_models/blinduser_viewmodel.dart';
import 'package:blind_user_app/views/blinduser_homepage.dart';

class CallRedirector extends StatefulWidget {
  final Widget child;

  const CallRedirector({super.key, required this.child});

  @override
  State<CallRedirector> createState() => _CallRedirectorState();
}

class _CallRedirectorState extends State<CallRedirector> {
  bool _wasRinging = false;
  bool _wasInCall = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = Provider.of<BlindUserViewModel>(context);
    viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    Provider.of<BlindUserViewModel>(context, listen: false)
        .removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() {
    final viewModel =
        Provider.of<BlindUserViewModel>(context, listen: false);

    final isRinging = viewModel.isRinging;
    final isInCall = viewModel.isInCall;

    if (isRinging && !isInCall && !_wasRinging) {
      _wasRinging = true;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const BlindUserHomePage(),
          settings: const RouteSettings(name: '/call'),
        ),
      );
    }

    // Fermer la page si l’appel se termine
    if (!isInCall && _wasInCall) {
      if (Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.settings.name != '/call');
      }
    }

    _wasRinging = isRinging;
    _wasInCall = isInCall;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
