import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/providers/work_order_provider.dart';

/// Controllable [WorkOrderProvider] test double for inbox provider tests.
class FakeWorkOrderProviderForInbox extends WorkOrderProvider {
  FakeWorkOrderProviderForInbox({
    required super.users,
    required super.assets,
    super.dataService,
    List<PMTask> pmTasks = const [],
  }) : _pmTasks = pmTasks;

  List<PMTask> _pmTasks;

  @override
  List<PMTask> get pmTasks => _pmTasks;

  void setPmTasks(List<PMTask> tasks) {
    _pmTasks = tasks;
    notifyListeners();
  }
}
