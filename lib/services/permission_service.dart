import 'package:permission_handler/permission_handler.dart' as permission_handler;

/// Permission states
enum PermissionState {
  notDetermined,
  granted,
  denied,
}

/// Service for handling app permissions
class PermissionService {
  /// Check microphone permission status
  Future<PermissionState> checkMicrophonePermission() async {
    final status = await permission_handler.Permission.microphone.status;
    return _mapPermissionStatus(status);
  }

  /// Request microphone permission
  Future<PermissionState> requestMicrophonePermission() async {
    // Directly request the permission - this will show the system dialog on iOS
    // if the permission hasn't been asked yet
    final status = await permission_handler.Permission.microphone.request();
    return _mapPermissionStatus(status);
  }

  /// Check if microphone permission is granted
  Future<bool> isMicrophoneGranted() async {
    final status = await checkMicrophonePermission();
    return status == PermissionState.granted;
  }

  /// Check screen recording permission status
  /// Note: On iOS, ReplayKit doesn't have a "check" permission - it shows
  /// a system dialog when you first try to start recording.
  /// We return notDetermined to indicate the user needs to attempt recording.
  Future<PermissionState> checkScreenRecordingPermission() async {
    // ReplayKit will handle the permission dialog automatically when startCapture is called
    // There's no way to pre-check if the user has granted permission
    // The permission dialog appears the first time you try to record
    return PermissionState.notDetermined;
  }

  /// Request screen recording permission
  /// Note: This doesn't actually request permission - ReplayKit shows the dialog
  /// automatically when you call startCapture() in RecordingService
  Future<PermissionState> requestScreenRecordingPermission() async {
    // The actual permission request happens in RecordingService.startRecording()
    // when ReplayKit's startCapture is called
    return PermissionState.notDetermined;
  }

  /// Map permission status to our enum
  PermissionState _mapPermissionStatus(permission_handler.PermissionStatus status) {
    switch (status) {
      case permission_handler.PermissionStatus.granted:
      case permission_handler.PermissionStatus.limited:
        return PermissionState.granted;
      case permission_handler.PermissionStatus.denied:
        // On iOS, 'denied' can mean "not yet asked" OR "user denied once"
        // We'll treat it as notDetermined so the UI can show the request modal
        // The actual request() call will determine if dialog can be shown
        return PermissionState.notDetermined;
      case permission_handler.PermissionStatus.restricted:
      case permission_handler.PermissionStatus.permanentlyDenied:
        return PermissionState.denied;
      default:
        return PermissionState.notDetermined;
    }
  }
  
  /// Check if we should show the request rationale (user denied once before)
  Future<bool> shouldShowRequestRationale() async {
    final status = await permission_handler.Permission.microphone.status;
    // On iOS, if status is denied but not permanently denied,
    // it means user was asked once and denied
    return status == permission_handler.PermissionStatus.denied;
  }

  /// Open app settings (for when permissions are denied)
  Future<void> openAppSettings() async {
    await permission_handler.openAppSettings();
  }
}
