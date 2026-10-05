import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/library_provider.dart';
import '../providers/download_provider.dart';
import '../models/library_folder.dart';
import '../services/saf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings screen for app configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedDestinationUri = '';
  
  @override
  void initState() {
    super.initState();
    _loadDefaultDestination();
  }

  /// Load default destination from preferences
  Future<void> _loadDefaultDestination() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedDestinationUri = prefs.getString('default_destination_uri') ?? '';
    if (mounted) setState(() {});
  }

  /// Save default destination to preferences
  Future<void> _saveDefaultDestination(String uri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_destination_uri', uri);
    if (mounted) setState(() => _selectedDestinationUri = uri);
  }

  /// Select destination folder
  Future<void> _selectDestination() async {
    try {
      final safService = SafService.instance;
      safService.openDirectoryPicker();
      
      // Listen for folder selection
      safService.onDirectorySelected.first.then((uri) {
        _saveDefaultDestination(uri);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${e.toString()}')),
        );
      }
    }
  }

  /// Remove a folder from the library
  Future<void> _removeFolder(String uri) async {
    try {
      final libraryNotifier = ref.read(libraryProvider.notifier);
      await libraryNotifier.removeFolder(uri);
      
      // If this was the default destination, clear it
      if (_selectedDestinationUri == uri) {
        _saveDefaultDestination('');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final libraryState = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme section
          _buildSectionHeader('\ud83c\udfa8 TEMA'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tema'),
                  DropdownButton<ThemeMode>(
                    value: themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(themeModeProvider.notifier).setThemeMode(value);
                      }
                    },
                    items: ThemeMode.values.map((mode) {
                      return DropdownMenuItem<ThemeMode>(
                        value: mode,
                        child: Text(mode.displayName),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Default destination section
          _buildSectionHeader('\ud83d\udcc1 DESTINAZIONE PREDEFINITA'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cartella predefinita'),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Seleziona'),
                        onPressed: _selectDestination,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedDestinationUri.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDestinationUri.split('/').last,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (_selectedDestinationUri.isEmpty)
                    Text(
                      'Nessuna cartella selezionata',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.5)),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Download format section
          _buildSectionHeader('\ud83c\udfba FORMATO DOWNLOAD'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Formato predefinito per i download'),
                  const SizedBox(height: 8),
                  Text(
                    'Seleziona il formato audio per i download da YouTube',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _buildFormatSelector(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Library folders section
          _buildSectionHeader('\ud83c\udfb5 LIBRERIA INDICIZZATA'),
          const SizedBox(height: 8),
          
          // Add folder button
          Card(
            child: ListTile(
              leading: const Icon(Icons.add, color: Color(0xFFFF9800)),
              title: const Text('Aggiungi cartella'),
              subtitle: const Text('Aggiungi una cartella alla libreria'),
              onTap: () async {
                try {
                  final safService = SafService.instance;
                  safService.openDirectoryPicker();
                  
                  // Listen for folder selection
                  safService.onDirectorySelected.first.then((uri) async {
                    final displayName = await safService.getDisplayName(uri);
                    
                    // Add folder to library
                    final libraryNotifier = ref.read(libraryProvider.notifier);
                    await libraryNotifier.addFolder(uri, displayName);
                    
                    // Scan the folder
                    await libraryNotifier.scanFolder(uri);
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Errore: ${e.toString()}')),
                    );
                  }
                }
              },
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Folders list
          if (libraryState.folders.isNotEmpty)
            Column(
              children: libraryState.folders.map((folder) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.folder, color: Color(0xFFFF9800)),
                    title: Text(folder.name),
                    subtitle: Text('${folder.songCount} brani'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeFolder(folder.uri),
                      tooltip: 'Rimuovi',
                    ),
                    onTap: () {
                      // Scan this folder
                      ref.read(libraryProvider.notifier).scanFolder(folder.uri);
                    },
                  ),
                );
              }).toList(),
            ),
          
          if (libraryState.folders.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nessuna cartella aggiunta alla libreria',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Scan all folders button
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Scansiona tutte le cartelle'),
            onPressed: () => ref.read(libraryProvider.notifier).scanAllFolders(),
          ),
          
          const SizedBox(height: 24),
          
          // Version section
          _buildSectionHeader('\u2139\ufe0f INFORMAZIONI'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Versione: 1.0.0'),
                  const SizedBox(height: 4),
                  Text(
                    'scariCANO - App di musica con supporto USB OTG',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Build format selector dropdown
  Widget _buildFormatSelector() {
    final downloadState = ref.watch(downloadProvider);
    final defaultFormat = downloadState.defaultFormat;
    
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<AudioFormat>(
            value: defaultFormat,
            onChanged: (value) {
              if (value != null) {
                ref.read(downloadProvider.notifier).setDefaultFormat(value);
              }
            },
            items: AudioFormat.values.map((format) {
              return DropdownMenuItem<AudioFormat>(
                value: format,
                child: Row(
                  children: [
                    Text(format.displayName),
                    const SizedBox(width: 8),
                    Text(
                      format.fileExtension,
                      style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Build section header
  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
