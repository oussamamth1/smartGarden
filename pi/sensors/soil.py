"""Capacitive soil moisture via the ADS1115 ADC (the Pi has no analog input).

Returns moisture as a 0-100% value, calibrated from the dry/wet voltages in config.
"""
import config

_channel = None


def _get_channel():
    global _channel
    if _channel is not None:
        return _channel
    import board
    import busio
    import adafruit_ads1x15.ads1115 as ADS
    from adafruit_ads1x15.analog_in import AnalogIn

    i2c = busio.I2C(board.SCL, board.SDA)
    ads = ADS.ADS1115(i2c)
    pin = getattr(ADS, f"P{config.ADS1115_SOIL_CHANNEL}")
    _channel = AnalogIn(ads, pin)
    return _channel


def _to_percent(voltage: float) -> float:
    dry, wet = config.SOIL_DRY_VOLTAGE, config.SOIL_WET_VOLTAGE
    pct = (dry - voltage) / (dry - wet) * 100.0
    return round(max(0.0, min(100.0, pct)), 1)


def read() -> dict:
    """Return {'soil_moisture': percent}."""
    if config.MOCK_HARDWARE:
        return {"soil_moisture": 42.0}
    return {"soil_moisture": _to_percent(_get_channel().voltage)}
