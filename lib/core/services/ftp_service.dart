import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_ftp_client/flutter_ftp_client.dart';
import 'package:file_upload/features/authentication/domain/entities/ftp_credentials.dart';

class FTPService {
  static final FTPService _instance = FTPService._internal();
  factory FTPService() => _instance;
  FTPService._internal();

  FtpConnection? _connection;
  bool _isConnected = false;
  bool _isConnecting = false; // Track if a connection attempt is in progress
 FTPCredentials? _lastCredentials;
  
  // Add a simple lock mechanism to prevent concurrent operations
  Completer<void>? _connectionLock;

  bool get isConnected => _isConnected;

  /// Connect to FTP server using provided credentials
  Future<bool> connect(FTPCredentials credentials) async {
    print(
        'FTPService.connect: Attempting to connect to ${credentials.hostname}:${credentials.port}');
    print(
        'FTPService.connect: Credentials - Username: ${credentials.username}, Secure: ${credentials.isSecure}');

    // If we're already connected with the same credentials, return true
    if (_isConnected &&
        _lastCredentials != null &&
        _credentialsMatch(_lastCredentials!, credentials)) {
      print('FTPService.connect: Already connected with same credentials');
      // Even if credentials match, verify the connection is still active
      bool stillConnected = await checkConnection();
      if (stillConnected) {
        print('FTPService.connect: Confirmed connection is still active');
        return true;
      } else {
        print('FTPService.connect: Connection was lost, will reconnect');
      }
    }

    // Prevent multiple simultaneous connection attempts
    if (_isConnecting) {
      print(
          'FTPService.connect: Connection attempt already in progress, waiting...');
      // Wait a bit and then check if connection was established by the other attempt
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isConnected) {
        print(
            'FTPService.connect: Connection was established by another attempt');
        return true;
      }
    }

    // If we're connected with different credentials, disconnect first
    if (_isConnected) {
      print(
          'FTPService.connect: Connected with different credentials or connection lost, disconnecting first...');
      await disconnect();
    }

    _isConnecting = true; // Mark that a connection attempt is in progress
    try {
      _connection = FtpConnection(
        host: credentials.hostname,
        port: credentials.port,
        username: credentials.username,
        password: credentials.password,
        isSecure: credentials.isSecure,
        passive: true, // Use passive mode by default
        timeout: 30000, // 30 second timeout
      );

      print('FTPService.connect: Created FtpConnection: $_connection');
      print('FTPService.connect: Calling FtpClient.connect...');
      _isConnected = await FtpClient.connect(_connection!);
      print('FTPService.connect: Connection result: $_isConnected');

      if (_isConnected) {
        _lastCredentials = credentials;
        print(
            'FTPService.connect: Successfully connected and stored credentials');
      } else {
        print('FTPService.connect: Connection failed, cleaning up state');
        _connection = null;
        _lastCredentials = null;
      }

      return _isConnected;
    } catch (e) {
      print('FTPService.connect: Error connecting: $e');
      _isConnected = false;
      _connection = null;
      _lastCredentials = null;
      rethrow;
    } finally {
      _isConnecting = false; // Always reset the connecting flag
    }
  }

  /// Check if two sets of credentials match
  bool _credentialsMatch(FTPCredentials c1, FTPCredentials c2) {
    return c1.hostname == c2.hostname &&
        c1.port == c2.port &&
        c1.username == c2.username &&
        c1.isSecure == c2.isSecure;
  }

  /// Disconnect from FTP server
  Future<bool> disconnect() async {
    if (!_isConnected) return true;

    try {
      await FtpClient.disconnect();
      _isConnected = false;
      _connection = null;
      _lastCredentials = null;
      print('FTPService.disconnect: Disconnected successfully');
      return true;
    } catch (e) {
      print('FTPService.disconnect: Error disconnecting: $e');
      _isConnected = false;
      _connection = null;
      _lastCredentials = null;
      return false;
    }
  }

  /// Check if currently connected
  Future<bool> checkConnection() async {
    print(
        'FTPService.checkConnection: Current _isConnected state: $_isConnected');
    if (!_isConnected) {
      print('FTPService.checkConnection: Not connected, returning false');
      return false;
    }

    try {
      bool connected = await FtpClient.isConnected();
      print(
          'FTPService.checkConnection: FtpClient.isConnected() result: $connected');

      if (!connected) {
        _isConnected = false;
        _connection = null;
        _lastCredentials = null;
      } else {
        // If the connection is active, update the internal state to reflect this
        _isConnected = true;
      }

      return connected;
    } catch (e) {
      print('FTPService.checkConnection: Error checking connection: $e');
      _isConnected = false;
      _connection = null;
      _lastCredentials = null;
      return false;
    }
  }

  /// Force a fresh connection, disconnecting any existing connection first
  Future<bool> forceConnect(FTPCredentials credentials) async {
    print(
        'FTPService.forceConnect: Forcing fresh connection to ${credentials.hostname}');

    // Always disconnect first to ensure we start fresh
    if (_isConnected) {
      await disconnect();
    }

    // Connect with the provided credentials
    bool result = await connect(credentials);
    print('FTPService.forceConnect: Result: $result');
    return result;
  }

  /// Test connection with credentials
  Future<bool> testConnection(FTPCredentials credentials) async {
    bool connected = false;
    try {
      connected = await connect(credentials);
      return connected;
    } finally {
      if (connected) {
        await disconnect();
      }
    }
  }

  /// Ensure connection with credentials before performing operations
 Future<void> _ensureConnection(FTPCredentials credentials) async {
    print(
        'FTPService._ensureConnection: Starting with credentials for ${credentials.hostname}');
    print(
        'FTPService._ensureConnection: Current state - _isConnected: $_isConnected, _lastCredentials: $_lastCredentials');

    // Wait for any existing connection lock to be released
    if (_connectionLock != null) {
      print('FTPService._ensureConnection: Waiting for connection lock to be released');
      await _connectionLock!.future;
    }

    // Create a new connection lock
    _connectionLock = Completer<void>();
    
    try {
      // Check if we're already connected with the same credentials
      if (_isConnected && _lastCredentials != null) {
        print('FTPService._ensureConnection: Checking if credentials match');
        bool credentialsMatch = _credentialsMatch(_lastCredentials!, credentials);
        print(
            'FTPService._ensureConnection: Credentials match: $credentialsMatch');

        if (credentialsMatch) {
          // Check if the current connection is still valid
          bool validConnection = await checkConnection();
          print(
              'FTPService._ensureConnection: Connection validity: $validConnection');

          if (validConnection) {
            print('FTPService._ensureConnection: Reusing existing connection');
            return;
          } else {
            print(
                'FTPService._ensureConnection: Connection is not valid, will reconnect');
          }
        } else {
          print(
              'FTPService._ensureConnection: Credentials do not match, will reconnect');
        }
      } else {
        print(
            'FTPService._ensureConnection: Not connected or no last credentials, will connect');
      }

      // If not connected or connection is invalid, connect with the provided credentials
      print(
          'FTPService._ensureConnection: Attempting to connect with provided credentials');
      bool connectResult = await connect(credentials);
      print('FTPService._ensureConnection: Connect result: $connectResult');

      // If still not connected after attempt, throw an exception
      if (!_isConnected || !connectResult) {
        print('FTPService._ensureConnection: Failed to establish connection');
        // Disconnect to ensure clean state before retry
        await disconnect();
        // Try one more time to ensure we don't have a timing issue
        print('FTPService._ensureConnection: Retrying connection once more...');
        await Future.delayed(
            const Duration(milliseconds: 500)); // Small delay before retry
        connectResult = await connect(credentials);
        print(
            'FTPService._ensureConnection: Retry connect result: $connectResult');

        if (!_isConnected || !connectResult) {
          print(
              'FTPService._ensureConnection: Failed to establish connection after retry');
          throw Exception('Failed to connect to FTP server');
        }
      }

      print('FTPService._ensureConnection: Connection established successfully');
      // Small delay to ensure connection is properly established
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      // Release the connection lock
      if (_connectionLock != null && !_connectionLock!.isCompleted) {
        _connectionLock!.complete();
        _connectionLock = null;
      }
    }
 }

  /// List directory contents
  Future<List<FtpFile>> listDirectory(
      String? path, FTPCredentials credentials) async {
    print(
        'FTPService.listDirectory: Attempting to list directory with path: $path');

    await _ensureConnection(credentials);

    if (!_isConnected) {
      print('FTPService.listDirectory: Not connected to FTP server');
      throw Exception('Not connected to FTP server');
    }

    try {
      final result = await FtpClient.listDirectory(path);
      print(
          'FTPService.listDirectory: Successfully listed directory, found ${result.length} items');
      for (int i = 0; i < result.length; i++) {
        print(
            ' Item $i: name="${result[i].name}", path="${result[i].path}", isDirectory=${result[i].isDirectory}');
      }
      return result;
    } catch (e) {
      print('FTPService.listDirectory: Error listing directory: $e');
      // If we get an error, the connection might be lost, so reset the state
      _isConnected = false;
      _connection = null;
      _lastCredentials = null;
      rethrow;
    }
  }

  /// Upload a file to FTP server
  Future<bool> uploadFile({
    required String localPath,
    required String remotePath,
    Function(double progress)? onProgress,
    required FTPCredentials credentials,
  }) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.uploadFile(
      localPath: localPath,
      remotePath: remotePath,
      onProgress: onProgress,
    );
  }

  /// Upload bytes to FTP server
  Future<bool> uploadBytes({
    required Uint8List bytes,
    required String remotePath,
    Function(double progress)? onProgress,
    required FTPCredentials credentials,
  }) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.uploadBytes(
      bytes: bytes,
      remotePath: remotePath,
      onProgress: onProgress,
    );
  }

  /// Download a file from FTP server
  Future<bool> downloadFile({
    required String remotePath,
    required String localPath,
    Function(double progress)? onProgress,
    required FTPCredentials credentials,
  }) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.downloadFile(
      remotePath: remotePath,
      localPath: localPath,
      onProgress: onProgress,
    );
  }

  /// Download file as bytes
  Future<Uint8List?> downloadBytes({
    required String remotePath,
    Function(double progress)? onProgress,
    required FTPCredentials credentials,
  }) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.downloadBytes(
      remotePath: remotePath,
      onProgress: onProgress,
    );
  }

  /// Delete a file from FTP server
  Future<bool> deleteFile(String remotePath, FTPCredentials credentials) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.deleteFile(remotePath);
  }

  /// Rename/move a file on FTP server
  Future<bool> renameFile(
      String oldPath, String newPath, FTPCredentials credentials) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.renameFile(oldPath, newPath);
  }

  /// Create a directory on FTP server
  Future<bool> createDirectory(String path, FTPCredentials credentials) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.createDirectory(path);
  }

  /// Delete a directory from FTP server
  Future<bool> deleteDirectory(String path, FTPCredentials credentials) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.deleteDirectory(path);
  }

  /// Change current working directory
  Future<bool> changeDirectory(String path, FTPCredentials credentials) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.changeDirectory(path);
  }

  /// Get current working directory
  Future<String?> getCurrentDirectory(FTPCredentials credentials) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.getCurrentDirectory();
  }

  /// Get file size
  Future<int?> getFileSize(
      String remotePath, FTPCredentials credentials) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.getFileSize(remotePath);
  }

  /// Check if file exists
  Future<bool> fileExists(String remotePath, FTPCredentials credentials) async {
    await _ensureConnection(credentials);

    if (!_isConnected) {
      throw Exception('Not connected to FTP server');
    }
    return await FtpClient.fileExists(remotePath);
  }
}
