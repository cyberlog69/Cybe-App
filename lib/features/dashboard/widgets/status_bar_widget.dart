import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../network_dashboard/bloc/network_bloc.dart';

class StatusBarWidget extends StatelessWidget {
  const StatusBarWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkBloc, NetworkState>(
      builder: (context, state) {
        final connected = state is NetworkConnected;
        final color = connected ? AppTheme.safe : AppTheme.danger;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                connected ? 'Network Connected' : 'Network Offline',
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (state is NetworkConnected) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    state.connectionType,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
