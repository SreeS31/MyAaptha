import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class HealthAnalysisCard extends StatefulWidget {
  const HealthAnalysisCard(
      {super.key, required this.api, required this.onSaved, this.selectReport});
  final MyAapthaApi api;
  final Future<void> Function() onSaved;
  final Future<PlatformFile?> Function()? selectReport;
  @override
  State<HealthAnalysisCard> createState() => _HealthAnalysisCardState();
}

class _HealthAnalysisCardState extends State<HealthAnalysisCard>
    with WidgetsBindingObserver {
  bool loading = true, enabled = false, consent = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      consent = false;
      enabled = false;
      error = null;
    });
    try {
      final policy = await widget.api.healthAnalysisPolicy();
      if (mounted) {
        setState(() => enabled = policy['configured'] == true &&
            policy['provider'] == 'OpenAI' &&
            policy['consentRequired'] == true);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> upload() async {
    if (!enabled || !consent || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final PlatformFile? file;
      if (widget.selectReport != null) {
        file = await widget.selectReport!();
      } else {
        file = (await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                withData: true,
                allowMultiple: false))
            ?.files
            .single;
      }
      if (file == null) return;
      if (file.bytes == null) {
        throw const FormatException(
            'Could not read the report. Please select it again.');
      }
      await widget.api.analyzeHealthReport(file.bytes!, file.name,
          processingConsent: consent);
      await widget.onSaved();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          consent = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Report analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (loading)
              const LinearProgressIndicator()
            else if (enabled)
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consent,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => consent = value == true),
                  title: const Text(
                      'I consent to sending this report to OpenAI for processing.'),
                  subtitle: const Text(
                      'Results are saved to your private health records. Review them against the original report.'))
            else
              const Text(
                  'Report analysis is disabled or unavailable. Manual entry is available.'),
            if (error != null)
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            FilledButton.icon(
                onPressed:
                    enabled && consent && !busy && !loading ? upload : null,
                icon: const Icon(Icons.upload_file),
                label: Text(busy ? 'Analyzing report...' : 'Analyze report')),
            if (!loading && !busy)
              TextButton(
                  onPressed: load, child: const Text('Check availability')),
          ])));
}
