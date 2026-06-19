"""BME280: temperature (°C), humidity (%), pressure (hPa) over I2C."""
import config

_sensor = None


def _get_sensor():
    global _sensor
    if _sensor is not None:
        return _sensor
    import board
    import busio
    from adafruit_bme280 import basic as adafruit_bme280

    i2c = busio.I2C(board.SCL, board.SDA)
    _sensor = adafruit_bme280.Adafruit_BME280_I2C(
        i2c, address=config.BME280_I2C_ADDRESS
    )
    return _sensor


def read() -> dict:
    """Return {'temperature', 'humidity', 'pressure'}."""
    if config.MOCK_HARDWARE:
        return {"temperature": 24.5, "humidity": 58.0, "pressure": 1013.2}
    s = _get_sensor()
    return {
        "temperature": round(s.temperature, 1),
        "humidity": round(s.humidity, 1),
        "pressure": round(s.pressure, 1),
    }
