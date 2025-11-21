#!/usr/bin/env python3
"""
Persistent traffic generators for ML-SDN testing
Maintains SINGLE long-lived TCP connections with traffic patterns
"""
import socket
import time
import sys
import argparse


def ssh_server(port=22):
    """SSH-like server: Accept ONE connection, send small bursts when requested"""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', port))
    server.listen(1)
    print(f"SSH server listening on port {port}", flush=True)

    conn, addr = server.accept()
    print(f"SSH connection from {addr}", flush=True)

    try:
        while True:
            # Wait for client request
            data = conn.recv(1)
            if not data:
                break
            # Send 100KB response (SSH echo pattern)
            conn.sendall(b'X' * 102400)  # 100KB
    except:
        pass

    conn.close()
    server.close()


def ssh_client(host, port=22, duration=300):
    """SSH-like client: Maintain ONE connection, send requests every 3s"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10)  # 10 second timeout for connect

    try:
        sock.connect((host, port))
    except Exception as e:
        print(f"SSH client connection FAILED to {host}:{port} - {e}", flush=True)
        return

    sock.settimeout(None)  # Remove timeout for data transfer
    print(f"SSH client connected to {host}:{port}", flush=True)

    start_time = time.time()
    burst_count = 0

    try:
        while time.time() - start_time < duration:
            # Send request (1 byte)
            sock.sendall(b'R')
            # Receive 100KB response
            received = 0
            while received < 102400:
                data = sock.recv(8192)
                if not data:
                    break
                received += len(data)
            burst_count += 1
            print(f"SSH burst {burst_count}: sent 1B, received {received}B", flush=True)
            time.sleep(3)
    except Exception as e:
        print(f"SSH client error: {e}", flush=True)

    sock.close()
    print(f"SSH client done: {burst_count} bursts", flush=True)


def ftp_server(port=21):
    """FTP-like server: Accept ONE connection, send bulk data continuously"""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', port))
    server.listen(1)
    print(f"FTP server listening on port {port}", flush=True)

    conn, addr = server.accept()
    print(f"FTP connection from {addr}", flush=True)

    try:
        while True:
            # Wait for client request
            data = conn.recv(1)
            if not data:
                break
            # Send 10MB file
            sent = 0
            chunk = b'Y' * 65536  # 64KB chunks
            while sent < 10485760:  # 10MB
                conn.sendall(chunk)
                sent += len(chunk)
    except:
        pass

    conn.close()
    server.close()


def ftp_client(host, port=21, duration=300):
    """FTP-like client: Maintain ONE connection, request 10MB files every 15s"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10)  # 10 second timeout for connect

    try:
        sock.connect((host, port))
    except Exception as e:
        print(f"FTP client connection FAILED to {host}:{port} - {e}", flush=True)
        return

    sock.settimeout(None)  # Remove timeout for data transfer
    print(f"FTP client connected to {host}:{port}", flush=True)

    start_time = time.time()
    transfer_count = 0

    try:
        while time.time() - start_time < duration:
            # Send request (1 byte)
            sock.sendall(b'G')
            # Receive 10MB response
            received = 0
            while received < 10485760:
                data = sock.recv(65536)
                if not data:
                    break
                received += len(data)
            transfer_count += 1
            print(f"FTP transfer {transfer_count}: received {received}B", flush=True)
            time.sleep(15)
    except Exception as e:
        print(f"FTP client error: {e}", flush=True)

    sock.close()
    print(f"FTP client done: {transfer_count} transfers", flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Persistent traffic generators')
    parser.add_argument('mode', choices=['ssh-server', 'ssh-client', 'ftp-server', 'ftp-client'])
    parser.add_argument('--host', help='Server host (for client modes)')
    parser.add_argument('--port', type=int, help='Port number')
    parser.add_argument('--duration', type=int, default=300, help='Duration in seconds (for client modes)')

    args = parser.parse_args()

    if args.mode == 'ssh-server':
        ssh_server(port=args.port or 22)
    elif args.mode == 'ssh-client':
        ssh_client(args.host, port=args.port or 22, duration=args.duration)
    elif args.mode == 'ftp-server':
        ftp_server(port=args.port or 21)
    elif args.mode == 'ftp-client':
        ftp_client(args.host, port=args.port or 21, duration=args.duration)
