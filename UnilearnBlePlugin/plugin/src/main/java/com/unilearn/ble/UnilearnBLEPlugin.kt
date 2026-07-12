package com.unilearn.ble

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.bluetooth.le.AdvertiseCallback.ADVERTISE_FAILED_FEATURE_UNSUPPORTED
import android.bluetooth.le.AdvertiseCallback.ADVERTISE_FAILED_INTERNAL_ERROR
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.pow
import kotlin.math.round

class UnilearnBLEPlugin(godot: Godot) : GodotPlugin(godot) {
    companion object {
        private const val UNILEARN_SERVICE_UUID_STRING = "0000fff0-0000-1000-8000-00805f9b34fb"
        private const val UNILEARN_NAME_UUID_STRING = "0000fff1-0000-1000-8000-00805f9b34fb"
        private const val MAX_NAME_PAYLOAD_BYTES = 20
        private const val REQUEST_ENABLE_BLUETOOTH = 8201
        private const val REQUEST_BLE_PERMISSIONS = 8202
        private const val UPDATE_INTERVAL_MS = 500L
        private const val LOST_TIMEOUT_MS = 2_500L
        private const val TX_POWER_AT_ONE_METER = -59.0
        private const val ENVIRONMENT_FACTOR = 2.2
        private const val RSSI_ALPHA = 0.25
        private const val UID_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        private const val TAG = "UnilearnBLE"
        private const val DEBUG_HEARTBEAT_MS = 5_000L
    }

    private val unilearnServiceUuid = ParcelUuid(UUID.fromString(UNILEARN_SERVICE_UUID_STRING))
    private val unilearnNameUuid = ParcelUuid(UUID.fromString(UNILEARN_NAME_UUID_STRING))

    private data class Peer(
        val uid: String,
        var displayName: String,
        var filteredRssi: Double,
        var lastSeenMs: Long,
        var distanceMeters: Double
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private val peers = ConcurrentHashMap<String, Peer>()
    private var adapter: BluetoothAdapter? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null
    private var advertising = false
    private var scanning = false
    private var localUid = ""
    private var localDisplayName = ""
    private var lastSignature = ""
    private var lastDebugHeartbeatMs = 0L
    private var rawScanCount = 0L
    private var lastRawScanLogMs = 0L

    override fun getPluginName() = "UnilearnBLE"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("nearby_players_changed", String::class.java),
        SignalInfo("discovery_error", String::class.java),
        SignalInfo("discovery_state_changed", Boolean::class.javaObjectType),
        SignalInfo("debug_log", String::class.java)
    )

    private fun debug(message: String) {
        Log.d(TAG, message)
        mainHandler.post { emitSignal("debug_log", message) }
    }

    private fun fail(code: String, details: String = "") {
        val message = if (details.isBlank()) code else "$code | $details"
        Log.e(TAG, message)
        mainHandler.post {
            emitSignal("debug_log", "ERROR: $message")
            emitSignal("discovery_error", code)
        }
    }

    @UsedByGodot
    fun getDebugSnapshot(): String {
        val a = getAdapter()
        return JSONObject().apply {
            put("sdk", Build.VERSION.SDK_INT)
            put("supported", isSupported())
            put("permissions", hasPermissions())
            put("fineLocationPermission", activity?.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED)
            put("bluetoothEnabled", isBluetoothEnabled())
            put("advertisingSupported", isAdvertisingSupported())
            put("advertiserAvailable", try { a?.bluetoothLeAdvertiser != null } catch (_: Exception) { false })
            put("scannerAvailable", try { a?.bluetoothLeScanner != null } catch (_: Exception) { false })
            put("advertising", advertising)
            put("scanning", scanning)
            put("uidLength", localUid.length)
            put("displayName", localDisplayName)
            put("peerCount", peers.size)
        }.toString()
    }

    private fun getAdapter(): BluetoothAdapter? {
        if (adapter == null) {
            val manager = activity?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            adapter = manager?.adapter
        }
        return adapter
    }

    @UsedByGodot
    fun isSupported(): Boolean {
        val activity = activity ?: return false
        return activity.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE) && getAdapter() != null
    }

    @UsedByGodot
    fun isBluetoothEnabled(): Boolean {
        return try {
            getAdapter()?.isEnabled == true
        } catch (_: SecurityException) {
            false
        }
    }

    @UsedByGodot
    fun isAdvertisingSupported(): Boolean {
        return try {
            getAdapter()?.isMultipleAdvertisementSupported == true
        } catch (_: SecurityException) {
            false
        }
    }

    @UsedByGodot
    fun hasPermissions(): Boolean {
        val activity = activity ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            activity.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                activity.checkSelfPermission(Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED &&
                activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
                activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else {
            activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    @UsedByGodot
    fun requestPermissions() {
        val activity = activity ?: run { fail("ACTIVITY_NULL"); return }
        debug("Requesting BLE permissions on Android ${Build.VERSION.SDK_INT}")
        activity.runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                activity.requestPermissions(
                    arrayOf(
                        Manifest.permission.BLUETOOTH_SCAN,
                        Manifest.permission.BLUETOOTH_ADVERTISE,
                        Manifest.permission.BLUETOOTH_CONNECT,
                        Manifest.permission.ACCESS_FINE_LOCATION
                    ),
                    REQUEST_BLE_PERMISSIONS
                )
            } else {
                activity.requestPermissions(
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                    REQUEST_BLE_PERMISSIONS
                )
            }
        }
    }

    @UsedByGodot
    fun requestEnableBluetooth() {
        val activity = activity ?: run { fail("ACTIVITY_NULL"); return }
        debug("Requesting Bluetooth enable dialog")
        activity.runOnUiThread {
            try {
                activity.startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), REQUEST_ENABLE_BLUETOOTH)
            } catch (e: Exception) {
                fail("BLUETOOTH_ENABLE_FAILED", e.message ?: e.javaClass.simpleName)
            }
        }
    }

    @UsedByGodot
    fun startDiscovery(uid: String, displayName: String) {
        val requestedUid = uid.trim()
        debug("startDiscovery called | uidLength=${requestedUid.length} | snapshot=${getDebugSnapshot()}")

        mainHandler.post {
            try {
                debug("Startup step 1/8: entered Android main thread")
                localUid = requestedUid
                localDisplayName = displayName.trim()

                if (localUid.isEmpty()) {
                    fail("EMPTY_UID")
                    return@post
                }

                debug("Startup step 2/8: validating BLE support")
                if (!isSupported()) {
                    fail("BLE_UNSUPPORTED")
                    return@post
                }

                debug("Startup step 3/8: validating permissions")
                if (!hasPermissions()) {
                    fail("PERMISSION_DENIED")
                    return@post
                }

                debug("Startup step 4/8: validating Bluetooth state")
                if (!isBluetoothEnabled()) {
                    fail("BLUETOOTH_DISABLED")
                    return@post
                }

                debug("Startup step 5/8: validating advertising support")
                if (!isAdvertisingSupported()) {
                    fail("ADVERTISE_UNSUPPORTED")
                    return@post
                }

                // Only stop an actually active/initialized session. Calling the
                // platform stop APIs on a completely fresh startup is unnecessary
                // and was the point at which some devices terminated the process.
                debug("Startup step 6/8: clearing previous session")
                mainHandler.removeCallbacks(updateRunnable)
                if (scanning || scanner != null) {
                    stopScanningInternal()
                }
                if (advertising || advertiser != null) {
                    stopAdvertisingInternal()
                }
                peers.clear()
                lastSignature = ""
                lastDebugHeartbeatMs = 0L
                rawScanCount = 0L
                lastRawScanLogMs = 0L

                debug("Startup step 7/8: starting advertiser")
                startAdvertisingInternal()

                debug("Startup step 8/8: starting scanner")
                startScanningInternal()

                mainHandler.removeCallbacks(updateRunnable)
                mainHandler.post(updateRunnable)
                emitSignal("discovery_state_changed", true)
                debug("Discovery start requested | snapshot=${getDebugSnapshot()}")
            } catch (t: Throwable) {
                // Catch Throwable, not only Exception, so linkage errors and other
                // runtime failures are reported instead of silently killing Godot.
                Log.e(TAG, "FATAL_START_DISCOVERY", t)
                fail(
                    "START_DISCOVERY_CRASH",
                    "${t.javaClass.name}: ${t.message ?: "no message"}"
                )
            }
        }
    }

    @UsedByGodot
    fun updateIdentity(displayName: String) {
        mainHandler.post {
            localDisplayName = displayName.trim()
            if (advertising || advertiser != null) {
                stopAdvertisingInternal()
                startAdvertisingInternal()
            }
        }
    }

    @UsedByGodot
    fun stopDiscovery() {
        debug("stopDiscovery called | snapshot=${getDebugSnapshot()}")
        mainHandler.post {
            try {
                mainHandler.removeCallbacks(updateRunnable)
                if (scanning || scanner != null) stopScanningInternal()
                if (advertising || advertiser != null) stopAdvertisingInternal()
                peers.clear()
                if (lastSignature.isNotEmpty()) {
                    lastSignature = ""
                    emitSignal("nearby_players_changed", "[]")
                }
                emitSignal("discovery_state_changed", false)
            } catch (t: Throwable) {
                Log.e(TAG, "STOP_DISCOVERY_FAILURE", t)
                fail("STOP_DISCOVERY_CRASH", "${t.javaClass.name}: ${t.message ?: "no message"}")
            }
        }
    }

    @Suppress("MissingPermission")
    private fun startAdvertisingInternal() {
        val bluetoothAdapter = getAdapter() ?: return
        advertiser = bluetoothAdapter.bluetoothLeAdvertiser
        val target = advertiser ?: run {
            fail("ADVERTISER_UNAVAILABLE")
            return
        }

        val uidPayload = encodeUid(localUid) ?: run {
            fail("UID_ENCODING_FAILED", "uidLength=${localUid.length}")
            return
        }
        debug("Preparing advertisement | uidLength=${localUid.length} | payloadBytes=${uidPayload.size}")
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .setTimeout(0)
            .build()

        // Use 16-bit service data instead of manufacturer data. The previous
        // manufacturer ID (0xFFFE) is reserved and some Android/OEM stacks do
        // not deliver it reliably to app scan callbacks. UUID 0xFFF0 keeps the
        // packet small enough for legacy BLE advertising while carrying the
        // complete compressed Firebase UID.
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(unilearnServiceUuid)
            .addServiceData(unilearnServiceUuid, uidPayload)
            .build()

        // The UID nearly fills the primary 31-byte legacy advertisement, so the
        // display name is placed in the separate scan-response packet. Active
        // Android scans merge both packets into the same ScanRecord.
        val namePayload = encodeDisplayName(localDisplayName)
        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceData(unilearnNameUuid, namePayload)
            .build()

        try {
            target.startAdvertising(settings, data, scanResponse, advertiseCallback)
            debug("startAdvertising submitted | nameBytes=${namePayload.size} | name=$localDisplayName")
        } catch (e: SecurityException) {
            fail("PERMISSION_DENIED", e.message ?: "SecurityException")
        } catch (e: Exception) {
            fail("ADVERTISE_EXCEPTION", e.message ?: e.javaClass.simpleName)
        }
    }

    @Suppress("MissingPermission")
    private fun stopAdvertisingInternal() {
        try {
            advertiser?.stopAdvertising(advertiseCallback)
        } catch (_: Exception) {
        }
        advertising = false
        advertiser = null
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            advertising = true
            debug("Advertising started successfully | mode=${settingsInEffect?.mode} | tx=${settingsInEffect?.txPowerLevel}")
        }

        override fun onStartFailure(errorCode: Int) {
            advertising = false
            val reason = when (errorCode) {
                ADVERTISE_FAILED_DATA_TOO_LARGE -> "DATA_TOO_LARGE"
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "TOO_MANY_ADVERTISERS"
                ADVERTISE_FAILED_ALREADY_STARTED -> "ALREADY_STARTED"
                ADVERTISE_FAILED_INTERNAL_ERROR -> "INTERNAL_ERROR"
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "FEATURE_UNSUPPORTED"
                else -> "UNKNOWN"
            }
            fail("ADVERTISE_FAILED_$errorCode", reason)
        }
    }

    @Suppress("MissingPermission")
    private fun startScanningInternal() {
        scanner = getAdapter()?.bluetoothLeScanner
        val target = scanner ?: run {
            fail("SCANNER_UNAVAILABLE")
            return
        }

        try {
            // Use Android's genuinely unfiltered overload. We filter the
            // Unilearn service data ourselves in processScanResult().
            target.startScan(scanCallback)
            scanning = true
            debug("BLE scan started successfully using unfiltered overload | serviceUuid=$UNILEARN_SERVICE_UUID_STRING")
        } catch (e: SecurityException) {
            fail("PERMISSION_DENIED", e.message ?: "SecurityException")
        } catch (e: Exception) {
            fail("SCAN_EXCEPTION", e.message ?: e.javaClass.simpleName)
        }
    }

    @Suppress("MissingPermission")
    private fun stopScanningInternal() {
        try {
            scanner?.stopScan(scanCallback)
        } catch (_: Exception) {
        }
        scanning = false
        scanner = null
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            rawScanCount++
            val now = android.os.SystemClock.elapsedRealtime()
            if (now - lastRawScanLogMs >= 2_000L) {
                lastRawScanLogMs = now
                debug("Raw BLE scans received | count=$rawScanCount | latestRssi=${result.rssi}")
            }
            processScanResult(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach(::processScanResult)
        }

        override fun onScanFailed(errorCode: Int) {
            scanning = false
            val reason = when (errorCode) {
                SCAN_FAILED_ALREADY_STARTED -> "ALREADY_STARTED"
                SCAN_FAILED_APPLICATION_REGISTRATION_FAILED -> "APP_REGISTRATION_FAILED"
                ADVERTISE_FAILED_INTERNAL_ERROR -> "INTERNAL_ERROR"
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "FEATURE_UNSUPPORTED"
                else -> "UNKNOWN"
            }
            fail("ADVERTISE_FAILED_$errorCode", reason)
        }
    }

    private fun processScanResult(result: ScanResult) {
        val record = result.scanRecord ?: return
        val uidBytes = record.getServiceData(unilearnServiceUuid) ?: return
        debug("Unilearn service packet received | bytes=${uidBytes.size} | rssi=${result.rssi}")
        val uid = decodeUid(uidBytes) ?: run {
            debug("Ignored malformed Unilearn packet | bytes=${uidBytes.size} | rssi=${result.rssi}")
            return
        }
        if (uid == localUid) return

        val displayName = decodeDisplayName(record.getServiceData(unilearnNameUuid))
        if (displayName.isEmpty()) {
            debug("Ignored Unilearn peer without display name yet | uid=${uid.take(8)}...")
            return
        }

        val now = android.os.SystemClock.elapsedRealtime()
        peers.compute(uid) { _, old ->
            if (old == null) {
                val distance = estimateDistance(result.rssi.toDouble())
                debug("Peer discovered | uid=${uid.take(8)}... | rssi=${result.rssi} | distance=${round(distance * 10.0) / 10.0}m")
                Peer(uid, displayName, result.rssi.toDouble(), now, distance)
            } else {
                old.displayName = displayName
                old.filteredRssi = RSSI_ALPHA * result.rssi + (1.0 - RSSI_ALPHA) * old.filteredRssi
                old.lastSeenMs = now
                old.distanceMeters = estimateDistance(old.filteredRssi)
                old
            }
        }
    }

    private val updateRunnable = object : Runnable {
        override fun run() {
            if (!scanning && !advertising) return
            val now = android.os.SystemClock.elapsedRealtime()
            peers.entries.removeIf { now - it.value.lastSeenMs > LOST_TIMEOUT_MS }

            val sorted = peers.values.sortedWith(compareBy<Peer> { it.distanceMeters }.thenBy { it.uid })
            val signature = sorted.joinToString("|") {
                val bucket = round(it.distanceMeters * 2.0) / 2.0
                "${it.uid}:${it.displayName}:$bucket"
            }
            if (signature != lastSignature) {
                lastSignature = signature
                debug("Nearby list changed | peers=${sorted.size}")
                emitSignal("nearby_players_changed", playersToJson(sorted))
            }
            if (now - lastDebugHeartbeatMs >= DEBUG_HEARTBEAT_MS) {
                lastDebugHeartbeatMs = now
                debug("Heartbeat | advertising=$advertising | scanning=$scanning | rawScans=$rawScanCount | peers=${peers.size}")
            }
            mainHandler.postDelayed(this, UPDATE_INTERVAL_MS)
        }
    }

    private fun playersToJson(sorted: List<Peer>): String {
        val array = JSONArray()
        sorted.forEach { peer ->
            array.put(JSONObject().apply {
                put("uid", peer.uid)
                put("displayName", peer.displayName)
                put("rssi", round(peer.filteredRssi).toInt())
                put("distanceMeters", round(peer.distanceMeters * 10.0) / 10.0)
            })
        }
        return array.toString()
    }

    private fun estimateDistance(rssi: Double): Double {
        val raw = 10.0.pow((TX_POWER_AT_ONE_METER - rssi) / (10.0 * ENVIRONMENT_FACTOR))
        return raw.coerceIn(0.2, 100.0)
    }

    private fun encodeDisplayName(name: String): ByteArray {
        val clean = name.trim()
        if (clean.isEmpty()) return byteArrayOf()

        val output = ArrayList<Byte>()
        for (character in clean) {
            val bytes = character.toString().toByteArray(Charsets.UTF_8)
            if (output.size + bytes.size > MAX_NAME_PAYLOAD_BYTES) break
            bytes.forEach { output.add(it) }
        }
        return output.toByteArray()
    }

    private fun decodeDisplayName(bytes: ByteArray?): String {
        if (bytes == null || bytes.isEmpty()) return ""
        return bytes.toString(Charsets.UTF_8).trim()
    }

    private fun encodeUid(uid: String): ByteArray? {
        if (uid.length !in 1..40) return null
        val values = uid.map {
            val index = UID_ALPHABET.indexOf(it)
            if (index < 0) return null
            index
        }
        val output = ArrayList<Byte>()
        output.add(uid.length.toByte())
        var buffer = 0
        var bits = 0
        values.forEach { value ->
            buffer = (buffer shl 6) or value
            bits += 6
            while (bits >= 8) {
                bits -= 8
                output.add(((buffer shr bits) and 0xFF).toByte())
            }
        }
        if (bits > 0) output.add(((buffer shl (8 - bits)) and 0xFF).toByte())
        return output.toByteArray()
    }

    private fun decodeUid(bytes: ByteArray): String? {
        if (bytes.isEmpty()) return null
        val length = bytes[0].toInt() and 0xFF
        if (length !in 1..40) return null
        val builder = StringBuilder(length)
        var buffer = 0
        var bits = 0
        for (i in 1 until bytes.size) {
            buffer = (buffer shl 8) or (bytes[i].toInt() and 0xFF)
            bits += 8
            while (bits >= 6 && builder.length < length) {
                bits -= 6
                val index = (buffer shr bits) and 0x3F
                builder.append(UID_ALPHABET[index])
            }
        }
        return if (builder.length == length) builder.toString() else null
    }


}
