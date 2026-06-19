"""BH1750 ambient light sensor (lux) over I2C. Optional."""
import config

_sensor = None


def _get_sensor():
    global _sensor
    if _sensor is not None:
        return _sensor
    import board
    import busio
    import adafruit_bh1750

    i2c = busio.I2C(board.SCL, board.SDA)
    _sensor = adafruit_bh1750.BH1750(i2c)
    return _sensor


def read() -> dict:
    """Return {'light_level': lux}."""
    if config.MOCK_HARDWARE:
        return {"light_level": 720.0}
    return {"light_level": round(_get_sensor().lux, 1)}
