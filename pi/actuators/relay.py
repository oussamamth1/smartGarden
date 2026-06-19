"""Generic relay channel (pump, light). Wraps gpiozero with a mock fallback."""
import config


class Relay:
    def __init__(self, pin: int, name: str = ""):
        self.pin = pin
        self.name = name
        self._state = False
        self._device = None
        if not config.MOCK_HARDWARE:
            from gpiozero import OutputDevice

            # active_high=False suits typical active-LOW relay boards.
            self._device = OutputDevice(
                pin,
                active_high=config.RELAY_ACTIVE_HIGH,
                initial_value=False,
            )

    def on(self):
        self._state = True
        if self._device:
            self._device.on()

    def off(self):
        self._state = False
        if self._device:
            self._device.off()

    def set(self, value: bool):
        self.on() if value else self.off()

    @property
    def is_on(self) -> bool:
        return self._state
