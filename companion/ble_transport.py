"""
BLE transport for Pixel Agents Bridge — connects to ESP32 via Nordic UART Service.

Uses bleak (asyncio-based BLE library) with a background event loop thread
to provide synchronous send() for the bridge's main loop.
"""

import asyncio
import threading
import time
from typing import Optional

try:
    from bleak import BleakClient, BleakScanner
except ImportError:
    print("Error: bleak is required for BLE transport. Install with: pip install bleak")
    raise

# Nordic UART Service UUIDs
NUS_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
NUS_RX_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"  # Write to this (ESP32 receives)
NUS_TX_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"  # Notify from this (ESP32 sends)

SCAN_TIMEOUT_SEC = 10.0
CONNECT_TIMEOUT_SEC = 10.0

# Manufacturer data company ID (must match firmware BLE_MFG_COMPANY_ID)
MFG_COMPANY_ID = 0xFFFF


class BleTransport:
    """BLE transport using Nordic UART Service.

    Runs bleak's asyncio event loop on a background thread.
    Exposes synchronous connect/send/disconnect for the bridge.
    """

    def __init__(self, device_name: str = "PixelAgents"):
        self._device_name = device_name
        self._client: Optional[BleakClient] = None
        self._connected = False
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._thread: Optional[threading.Thread] = None
        self._start_event_loop()

    def _start_event_loop(self):
        """Start the asyncio event loop on a background thread."""
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()

    def _run_loop(self):
        """Run the asyncio event loop (background thread)."""
        asyncio.set_event_loop(self._loop)
        self._loop.run_forever()

    def _run_coro(self, coro, timeout: float = 30.0):
        """Run an async coroutine from the synchronous context."""
        future = asyncio.run_coroutine_threadsafe(coro, self._loop)
        return future.result(timeout=timeout)

    @property
    def is_connected(self) -> bool:
        return self._connected

    def scan(self) -> Optional[str]:
        """Scan for the PixelAgents device. Returns BLE address or None."""
        devices = self.scan_devices()
        if devices:
            addr, name, pin = devices[0]
            return addr
        return None

    def scan_devices(self) -> list:
        """Scan for NUS devices. Returns list of (address, name, pin) tuples."""
        return self._run_coro(self._scan_devices_async(), timeout=SCAN_TIMEOUT_SEC + 5)

    async def _scan_devices_async(self) -> list:
        print("Scanning for BLE devices (NUS service)...")
        devices = await BleakScanner.discover(
            timeout=SCAN_TIMEOUT_SEC,
            service_uuids=[NUS_SERVICE_UUID],
            return_adv=True
        )
        results = []
        for addr, (device, adv_data) in devices.items():
            pin = self._extract_pin(adv_data)
            name = adv_data.local_name or device.name or "Unknown"
            pin_str = f", PIN={pin}" if pin else ""
            print(f"  Found: {name} at {addr}{pin_str}")
            results.append((addr, name, pin))
        if not results:
            print("No NUS devices found.")
        return results

    @staticmethod
    def _extract_pin(adv_data) -> Optional[int]:
        """Extract PIN from manufacturer data in advertisement."""
        mfg = adv_data.manufacturer_data
        if not mfg:
            return None
        payload = mfg.get(MFG_COMPANY_ID)
        if payload is None or len(payload) < 2:
            return None
        return (payload[0] << 8) | payload[1]

    def connect_by_pin(self, pin: int) -> bool:
        """Scan for NUS devices and connect to the one matching the given PIN."""
        devices = self.scan_devices()
        for addr, name, dev_pin in devices:
            if dev_pin == pin:
                print(f"PIN {pin} matched: {name} at {addr}")
                return self.connect(address=addr)
        print(f"No device found with PIN {pin}")
        return False

    def connect(self, address: Optional[str] = None) -> bool:
        """Scan (if no address given) and connect to the device."""
        if address is None:
            address = self.scan()
        if address is None:
            return False
        try:
            return self._run_coro(
                self._connect_async(address), timeout=CONNECT_TIMEOUT_SEC + 5
            )
        except Exception as e:
            print(f"BLE connect failed: {e}")
            return False

    async def _connect_async(self, address: str) -> bool:
        # Disconnect previous client if any (e.g. reconnect after failure)
        if self._client:
            try:
                await self._client.disconnect()
            except Exception:
                pass
            self._client = None

        def on_disconnect(client):
            self._connected = False
            print("BLE disconnected.")

        self._client = BleakClient(address, disconnected_callback=on_disconnect)
        await self._client.connect(timeout=CONNECT_TIMEOUT_SEC)

        # Request larger MTU to avoid fragmentation on protocol messages
        if hasattr(self._client, "mtu_size"):
            print(f"BLE MTU: {self._client.mtu_size}")

        self._connected = True
        print(f"BLE connected to {address}")
        return True

    def send(self, data: bytes) -> bool:
        """Send data to the ESP32 via NUS RX characteristic."""
        if not self._connected or not self._client:
            return False
        try:
            self._run_coro(self._send_async(data), timeout=5.0)
            return True
        except Exception as e:
            print(f"BLE send error: {e}")
            self._connected = False
            return False

    async def _send_async(self, data: bytes):
        # Write without response for lower latency
        await self._client.write_gatt_char(NUS_RX_UUID, data, response=False)

    def disconnect(self):
        """Disconnect from the BLE device."""
        if self._client and self._connected:
            try:
                self._run_coro(self._client.disconnect(), timeout=5.0)
            except Exception:
                pass
        self._connected = False
        self._client = None

    def close(self):
        """Shut down the background event loop."""
        self.disconnect()
        if self._loop and self._loop.is_running():
            self._loop.call_soon_threadsafe(self._loop.stop)
        if self._thread:
            self._thread.join(timeout=2.0)
