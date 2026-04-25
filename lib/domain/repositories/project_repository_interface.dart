import '../../core/styles/project_style.dart';
import '../entities/project_snapshot.dart';

abstract class ProjectRepositoryInterface {
  Future<void> save(ProjectSnapshot snapshot, {ProjectStyleType? styleType});
  Future<ProjectSnapshot?> load({ProjectStyleType? styleType});
}
