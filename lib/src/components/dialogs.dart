import 'package:features_tour/src/models/predialog_config.dart';
import 'package:features_tour/src/utils/print_debug.dart';
import 'package:flutter/material.dart';

/// Save the state of the doNotAskAgain checkbox
bool? _doNotAskAgainResult;

/// Show the predialog with specific configuration
Future<bool?> predialog(BuildContext context, PredialogConfig config) async {
  // If `_dontAskAgainResult` is not null, the `doNotAksAgain` is checked
  // so just return the result.
  if (_doNotAskAgainResult != null) {
    printDebug(
        'Do not ask again is checked in the previous dialog, return previous result: $_doNotAskAgainResult');
    return _doNotAskAgainResult;
  }

  bool checkbox = false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return AlertDialog(
        title: Text(
          config.title,
          style: TextStyle(color: config.textColor),
        ),
        contentPadding:
            const EdgeInsets.only(bottom: 8, top: 20, left: 24, right: 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              config.content,
              style: TextStyle(color: config.textColor),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Checkbox(
                        value: checkbox,
                        side: BorderSide(color: config.textColor, width: 2),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              checkbox = value;
                            });
                          }
                        },
                      ),
                      GestureDetector(
                        child: Text(
                          config.doNotAskAgainText,
                          style: TextStyle(
                            color: config.textColor,
                            fontSize: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.fontSize,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            checkbox = !checkbox;
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     SizedBox(
            //       width: 90,
            //       child: ElevatedButton(
            //         onPressed: () {
            //           Navigator.pop(context, true);
            //         },
            //         child: Text(config.yesButtonText),
            //       ),
            //     ),
            //     const SizedBox(width: 16),
            //     SizedBox(
            //       width: 90,
            //       child: TextButton(
            //         onPressed: () {
            //           Navigator.pop(context, false);
            //         },
            //         child: Text(config.noButtonText),
            //       ),
            //     ),
            //   ],
            // ),
          ],
        ),
        backgroundColor: config.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(config.borderRadius),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: Text(config.yesButtonText),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: Text(config.noButtonText),
          ),
        ],
      );
    },
  );

  // If the dontAskAgain checkbox is checked, the global configuration will be
  // updated
  if (checkbox && result != null) {
    printDebug(
        'dontAskAgain checkbox is checked => Update global predialog configuration');
    _doNotAskAgainResult = result;
  }

  return result;
}
