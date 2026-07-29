import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../models/mesh_message.dart';
import '../models/peer_info.dart';
import '../services/composite_mesh_service.dart';
import '../services/mesh_service_interface.dart';
import '../services/mesh_crypto.dart';

const String _kPublicChannel = 'cybe-public';
const String _kPublicKey = '__PUBLIC_CHANNEL_PLAIN__';

MeshServiceInterface get _meshService => CompositeMeshService.instance;

class BleMeshScreen extends StatefulWidget {
  const BleMeshScreen({super.key});

  @override
  State<BleMeshScreen> createState() => _BleMeshScreenState();
}

class _BleMeshScreenState extends State<BleMeshScreen>
    with SingleTickerProviderStateMixin {
  // ─── State ──────────────────────────────────────────────────────────────────
  String _alias = 'Loading...';
  String _currentChannel = _kPublicChannel;
  String _currentChannelKey = _kPublicKey;
  bool _isRunning = false;
  bool _isStarting = false;

  final Map<String, List<_DisplayMessage>> _channelMessages = {
    _kPublicChannel: [],
  };
  final Map<String, String> _channelKeys = {
    _kPublicChannel: _kPublicKey,
  };
  List<String> get _channels => _channelMessages.keys.toList();

  List<MeshPeerInfo> _peers = [];

  // ─── Controllers ────────────────────────────────────────────────────────────
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  StreamSubscription<MeshMessage>? _msgSub;
  StreamSubscription<List<MeshPeerInfo>>? _peerSub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadAlias();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _msgSub?.cancel();
    _peerSub?.cancel();
    if (_isRunning) _meshService.stop();
    super.dispose();
  }

  Future<void> _loadAlias() async {
    final prefs = await SharedPreferences.getInstance();
    var alias = prefs.getString('bitmesh_alias');
    if (alias == null || alias.isEmpty) {
      alias = MeshCrypto.generateAlias();
      await prefs.setString('bitmesh_alias', alias);
    }
    if (mounted) setState(() => _alias = alias!);
  }

  Future<void> _toggleMesh() async {
    if (_isRunning) {
      await _meshService.stop();
      _msgSub?.cancel();
      _peerSub?.cancel();
      setState(() {
        _isRunning = false;
        _peers = [];
      });
    } else {
      setState(() => _isStarting = true);
      try {
        await _meshService.start(alias: _alias);
        _msgSub = _meshService.incomingMessages.listen(_onMessageReceived);
        _peerSub = _meshService.discoveredPeers.listen((peers) {
          if (mounted) setState(() => _peers = peers);
        });
        if (mounted) setState(() { _isRunning = true; _isStarting = false; });
      } catch (e) {
        if (mounted) {
          setState(() => _isStarting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start BitMesh: $e'),
              duration: const Duration(seconds: 4),
            ),
          );
        }

      }
    }
  }

  void _onMessageReceived(MeshMessage msg) {
    if (!mounted) return;
    final channel = msg.channel;

    // Decrypt if we have the key
    String displayText;
    final key = _channelKeys[channel];
    if (key == null) {
      // Unknown channel — add it with no key
      _channelMessages[channel] = [];
      _channelKeys[channel] = '';
      displayText = '[Encrypted — join channel to read]';
    } else if (key == _kPublicKey) {
      displayText = msg.encryptedData;
    } else {
      displayText = MeshCrypto.decrypt(msg.encryptedData, key) ??
          '[Cannot decrypt — wrong passphrase]';
    }

    setState(() {
      _channelMessages[channel] ??= [];
      _channelMessages[channel]!.add(_DisplayMessage(
        text: displayText,
        alias: msg.senderAlias,
        timestamp: msg.timestamp,
        isOwn: false,
        hops: msg.hops,
        isRelayed: msg.isRelayed,
      ));
    });
    if (channel == _currentChannel) _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _messageCtrl.clear();

    final encrypted = _currentChannelKey == _kPublicKey
        ? text
        : MeshCrypto.encrypt(text, _currentChannelKey);

    final delivered = await _meshService.sendMessage(
      channelName: _currentChannel,
      encryptedData: encrypted,
      senderAlias: _alias,
    );
    debugPrint('[BitMesh] Delivered to $delivered peers');

    setState(() {
      _channelMessages[_currentChannel] ??= [];
      _channelMessages[_currentChannel]!.add(_DisplayMessage(
        text: text,
        alias: _alias,
        timestamp: DateTime.now(),
        isOwn: true,
        hops: 0,
        isRelayed: false,
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showJoinChannelDialog() async {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Join / Create Channel',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Leave passphrase empty for a public unencrypted channel.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Channel Name',
                hintText: 'e.g. cybe-team',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_]')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Passphrase (optional)',
                hintText: 'Leave blank for public',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim().toLowerCase();
              final pass = passCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              _joinChannel(name, pass.isEmpty ? _kPublicKey : pass);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _joinChannel(String name, String key) {
    setState(() {
      if (!_channelMessages.containsKey(name)) {
        _channelMessages[name] = [];
        _channelKeys[name] = key;
      }
      _currentChannel = name;
      _currentChannelKey = _channelKeys[name] ?? _kPublicKey;
    });
  }

  Future<void> _showAliasDialog() async {
    final ctrl = TextEditingController(text: _alias);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Your Alias',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your display name on the mesh network.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Alias',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final alias = MeshCrypto.generateAlias();
              ctrl.text = alias;
            },
            child: const Text('Random', style: TextStyle(color: AppTheme.accent)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newAlias = ctrl.text.trim();
              if (newAlias.isEmpty) return;
              final navigator = Navigator.of(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('bitmesh_alias', newAlias);
              if (mounted) setState(() => _alias = newAlias);
              navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────


  @override
  Widget build(BuildContext context) {
    final messages = _channelMessages[_currentChannel] ?? [];
    final isPrivate = _currentChannelKey != _kPublicKey;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(isPrivate),
          Expanded(
            child: Row(
              children: [
                // Channel sidebar (desktop) or collapsible (mobile)
                if (MediaQuery.of(context).size.width >= 700)
                  _buildChannelSidebar(),
                // Main chat area
                Expanded(
                  child: Column(
                    children: [
                      _buildChannelHeader(isPrivate),
                      if (!_isRunning && !_isStarting) _buildOfflinePrompt(),
                      Expanded(child: _buildMessageList(messages)),
                      _buildInputBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isPrivate) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 8, bottom: 12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E30))),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // BLE pulse
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(
              opacity: _isRunning ? _pulseAnim.value : 0.3,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isRunning
                      ? const LinearGradient(
                          colors: [Color(0xFF7B2FBE), Color(0xFF00E5FF)],
                        )
                      : null,
                  color: _isRunning ? null : AppTheme.surfaceVariant,
                ),
                child: Icon(
                  Icons.bluetooth_rounded,
                  size: 20,
                  color: _isRunning ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppTheme.primaryGradient.createShader(b),
                  child: const Text(
                    'BitMesh',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Text(
                  _isRunning
                      ? '${_peers.length} peer${_peers.length != 1 ? 's' : ''} nearby • $_alias'
                      : 'Off-Grid Messenger • Tap ▶ to start',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          // Alias button
          IconButton(
            icon: const Icon(Icons.person_pin_rounded,
                color: AppTheme.textSecondary),
            tooltip: 'Change Alias',
            onPressed: _showAliasDialog,
          ),
          // Start/Stop button
          GestureDetector(
            onTap: _isStarting ? null : _toggleMesh,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: _isRunning
                    ? AppTheme.dangerGradient
                    : AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isStarting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isRunning ? 'Stop' : 'Start',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildChannelSidebar() {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: Color(0xFF1E1E30))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Text('CHANNELS',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      size: 16, color: AppTheme.primary),
                  onPressed: _showJoinChannelDialog,
                  tooltip: 'Join Channel',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: ListView.builder(
                itemCount: _channels.length,
                itemBuilder: (_, i) {
                  final ch = _channels[i];
                  final isSelected = ch == _currentChannel;
                  final isPublic = (_channelKeys[ch] ?? '') == _kPublicKey;
                  final msgCount = _channelMessages[ch]?.length ?? 0;
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
                    leading: Icon(
                      isPublic
                          ? Icons.public_rounded
                          : Icons.lock_rounded,
                      size: 14,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    title: Text(
                      '#$ch',
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: msgCount > 0
                        ? Text(
                            '$msgCount',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10),
                          )
                        : null,
                    onTap: () => setState(() {
                      _currentChannel = ch;
                      _currentChannelKey =
                          _channelKeys[ch] ?? _kPublicKey;
                    }),
                  );
                },
              ),
            ),
          ),
          // Peers section
          const Divider(color: Color(0xFF1E1E30)),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('NEARBY NODES',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
          ),
          SizedBox(
            height: 150,
            child: _peers.isEmpty
                ? const Center(
                    child: Text('No nodes found',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  )
                : Material(
                    color: Colors.transparent,
                    child: ListView.builder(
                      itemCount: _peers.length,
                      itemBuilder: (_, i) {
                        final p = _peers[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.bluetooth_connected_rounded,
                              size: 14,
                              color: p.rssi >= -70
                                  ? AppTheme.safe
                                  : AppTheme.warning),
                          title: Text(p.name,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${p.rssi} dBm \u2022 ${p.signalLabel}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10)),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildChannelHeader(bool isPrivate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.7),
        border: const Border(bottom: BorderSide(color: Color(0xFF1E1E30))),
      ),
      child: Row(
        children: [
          Icon(
            isPrivate ? Icons.lock_rounded : Icons.public_rounded,
            size: 16,
            color: isPrivate ? AppTheme.warning : AppTheme.safe,
          ),
          const SizedBox(width: 8),
          Text(
            '#$_currentChannel',
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isPrivate
                  ? AppTheme.warning.withValues(alpha: 0.12)
                  : AppTheme.safe.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isPrivate ? 'Encrypted' : 'Public',
              style: TextStyle(
                color: isPrivate ? AppTheme.warning : AppTheme.safe,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // Add channel on small screens
          if (MediaQuery.of(context).size.width < 700)
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  size: 18, color: AppTheme.primary),
              onPressed: _showJoinChannelDialog,
              tooltip: 'Join Channel',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _buildOfflinePrompt() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.accent.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Press Start to begin scanning for nearby Cybe nodes on your local network.',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<_DisplayMessage> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient.scale(0.15),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(Icons.bluetooth_searching_rounded,
                  color: AppTheme.primary, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('No messages yet',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              '#$_currentChannel',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (_, i) => _buildMessageBubble(messages[i]),
    );
  }

  Widget _buildMessageBubble(_DisplayMessage msg) {
    final isOwn = msg.isOwn;
    final time = DateFormat('HH:mm').format(msg.timestamp);

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment:
              isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Alias row
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg.isRelayed && !isOwn) ...[
                    const Icon(Icons.repeat_rounded,
                        size: 10, color: AppTheme.accent),
                    const SizedBox(width: 2),
                    Text('${msg.hops}hop  ',
                        style: const TextStyle(
                            color: AppTheme.accent, fontSize: 9)),
                  ],
                  Text(
                    isOwn ? 'You' : msg.alias,
                    style: TextStyle(
                      color:
                          isOwn ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(time,
                      style: const TextStyle(
                          color: Color(0xFF5A5A7A), fontSize: 9)),
                ],
              ),
            ),
            // Bubble
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isOwn
                    ? const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF7B2FBE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isOwn ? null : AppTheme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOwn ? 16 : 4),
                  bottomRight: Radius.circular(isOwn ? 4 : 16),
                ),
                border: isOwn
                    ? null
                    : Border.all(
                        color: const Color(0xFF1E1E30)),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isOwn ? Colors.white : AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Color(0xFF1E1E30))),
      ),
      child: Row(
        children: [
          // Channel selector (small screen)
          if (MediaQuery.of(context).size.width < 700)
            IconButton(
              icon: const Icon(Icons.tag_rounded,
                  color: AppTheme.textSecondary, size: 20),
              onPressed: _showChannelSheet,
              tooltip: 'Channels',
            ),
          Expanded(
            child: TextField(
              controller: _messageCtrl,
              enabled: _isRunning,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: _isRunning
                    ? 'Message #$_currentChannel...'
                    : 'Start BitMesh to send messages',
                hintStyle: const TextStyle(color: Color(0xFF5A5A7A)),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isRunning ? _sendMessage : null,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: _isRunning
                    ? AppTheme.primaryGradient
                    : null,
                color: _isRunning ? null : AppTheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: _isRunning ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChannelSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text('Channels',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Join'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                  onPressed: () {
                    Navigator.pop(context);
                    _showJoinChannelDialog();
                  },
                ),
              ],
            ),
          ),
          ..._channels.map((ch) {
            final isPublic = (_channelKeys[ch] ?? '') == _kPublicKey;
            return ListTile(
              leading: Icon(
                isPublic ? Icons.public_rounded : Icons.lock_rounded,
                color: ch == _currentChannel
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
              ),
              title: Text('#$ch',
                  style: TextStyle(
                      color: ch == _currentChannel
                          ? AppTheme.primary
                          : AppTheme.textPrimary)),
              trailing: ch == _currentChannel
                  ? const Icon(Icons.check_rounded, color: AppTheme.primary)
                  : null,
              onTap: () {
                setState(() {
                  _currentChannel = ch;
                  _currentChannelKey = _channelKeys[ch] ?? _kPublicKey;
                });
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Local display model ─────────────────────────────────────────────────────

class _DisplayMessage {
  final String text;
  final String alias;
  final DateTime timestamp;
  final bool isOwn;
  final int hops;
  final bool isRelayed;

  const _DisplayMessage({
    required this.text,
    required this.alias,
    required this.timestamp,
    required this.isOwn,
    required this.hops,
    required this.isRelayed,
  });
}

// ─── Gradient scale extension ─────────────────────────────────────────────────

extension GradientScale on LinearGradient {
  LinearGradient scale(double opacity) {
    return LinearGradient(
      colors: colors.map((c) => c.withValues(alpha: opacity)).toList(),
      begin: begin,
      end: end,
    );
  }
}
