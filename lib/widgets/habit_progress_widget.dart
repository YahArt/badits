import 'package:badits/helpers/date_time_helper.dart';
import 'package:badits/helpers/habit_duration_helper.dart';
import 'package:badits/models/colors.dart';
import 'package:badits/models/habit.dart';
import 'package:badits/models/habitStatusEntry.dart';
import 'package:badits/services/service_locator.dart';
import 'package:badits/services/storage_service.dart';
import 'package:badits/extensions/string_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HabitProgressWidget extends StatefulWidget {
  final Habit habit;
  final Function onHabitCompleteTaped;

  const HabitProgressWidget({Key key, this.habit, this.onHabitCompleteTaped})
      : super(key: key);

  @override
  _HabitProgressWidgetState createState() => _HabitProgressWidgetState();
}

class _HabitProgressWidgetState extends State<HabitProgressWidget> {
  final DateTime _now = DateTime.now();
  bool _habitInProgress = false;
  bool _habitCompleted = false;
  double _habitProgress = 0;
  String _nextDateString = '';
  GlobalKey _progressContainerKey = GlobalKey();

  Future<void> _update() async {
    // Update the completion count
    StorageService storageService = locator<StorageService>();
    final habitStatusEntries =
        await storageService.getHabitStatusEntriesForHabit(this.widget.habit);

    final habitStatusEntriesForToday =
        await storageService.getHabitStatusEntriesForDateTime(
            this.widget.habit, DateTimeHelper.getBaditsDateTimeString(_now));

    // Calculate the next completion date
    final nextCompletionDate = HabitDurationHelper.getNextCompletionDate(
        _now, this.widget.habit.duration);
    this.widget.habit.nextCompletionDate = nextCompletionDate;

    // Update the completion count
    this.widget.habit.currentCompletionCount = habitStatusEntries.length;

    // Determine if the habit is completed for today
    this.widget.habit.completedForToday = habitStatusEntriesForToday.length > 0;

    await storageService.updateHabit(this.widget.habit);

    // Because this method is called asynchronously in initState it could happen that the widget is not mounted yet.
    if (this.mounted) {
      setState(() {
        _habitInProgress = this.widget.habit.currentCompletionCount > 0 &&
            this.widget.habit.currentCompletionCount <
                this.widget.habit.countUntilCompletion;

        final RenderBox progressContainer =
            _progressContainerKey.currentContext.findRenderObject();
        final progressContainerWith = progressContainer.size.width;

        _habitProgress =
            (progressContainerWith / this.widget.habit.countUntilCompletion) *
                this.widget.habit.currentCompletionCount;

        final nextDate = this.widget.habit.nextCompletionDate;

        // Check if the habit was actually completed
        _habitCompleted = this.widget.habit.currentCompletionCount >=
            this.widget.habit.countUntilCompletion;

        if (_habitCompleted) {
          _nextDateString = 'Completed';
        } else {
          _nextDateString = this.widget.habit.isPassDueDate(_now)
              ? 'Pass Due'
              : 'Next: ${DateTimeHelper.getBaditsDateTimeString(nextDate)}';
        }
      });
    }
  }

  List<Widget> _getStackElements() {
    List<Widget> stackElements = [
      Container(
        color: BADITS_PINK,
        width: _habitProgress,
      ),
      Container(
        padding: EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deadline ${DateTimeHelper.getBaditsDateTimeString(this.widget.habit.dueDate)}',
                  style: TextStyle(
                      fontFamily: 'ObibokRegular',
                      fontSize: 10,
                      color: _habitInProgress ? Colors.white : Colors.black),
                ),
                Text('${this.widget.habit.name.truncateWithEllipsis(12)}',
                    style: TextStyle(
                        fontFamily: 'ObibokRegular',
                        fontSize: 20,
                        color: _habitInProgress ? Colors.white : Colors.black)),
                Spacer(),
                Container(
                  height: 45,
                  child: SvgPicture.asset(this.widget.habit.assetIcon,
                      color: _habitInProgress ? Colors.white : Colors.black),
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_nextDateString,
                    style: TextStyle(
                        fontFamily: 'ObibokRegular',
                        fontSize: 10,
                        color: _habitInProgress || _habitCompleted
                            ? Colors.black
                            : BADITS_PINK)),
                GestureDetector(
                    onTap: () async {
                      // if the habit has already been completed for today do nothing
                      if (this.widget.habit.completedForToday) {
                        return;
                      }
                      StorageService storageService = locator<StorageService>();
                      final HabitStatusEntry entry = HabitStatusEntry(
                          habitId: this.widget.habit.id, date: DateTime.now());
                      await storageService.insertHabitStatusEntry(entry);

                      // Awaiting here is important because if we do not the state is not reflected properly...
                      await _update();
                      this.widget.onHabitCompleteTaped();
                    },
                    child: Container(
                        margin: EdgeInsets.symmetric(vertical: 10),
                        child: SvgPicture.asset(
                            this.widget.habit.completedForToday
                                ? 'assets/icons/check_filled.svg'
                                : 'assets/icons/check.svg',
                            color: Colors.black))),
                Spacer(),
                Text(
                    '${this.widget.habit.currentCompletionCount}/${this.widget.habit.countUntilCompletion}',
                    style: TextStyle(
                        fontFamily: 'ObibokRegular',
                        fontSize: 15,
                        color: Colors.black))
              ],
            )
          ],
        ),
      )
    ];

    // In case the habit is already completed add a white overlay with an mid level opacity to create the disabled effect.
    if (this.widget.habit.completedForToday) {
      stackElements.add(Container(
        decoration: BoxDecoration(color: BADITS_DISABLED),
      ));
    }

    return stackElements;
  }

  @override
  void initState() {
    _update();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        key: _progressContainerKey,
        height: 100,
        margin: EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(color: BADITS_DARKER_GRAY),
        child: Stack(
          children: _getStackElements(),
        ));
  }
}
