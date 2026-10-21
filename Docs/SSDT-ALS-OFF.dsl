DefinitionBlock ("", "SSDT", 2, "ASUS", "ALSDIS", 0x00000001)
{
    External (_SB_.ATKD, DeviceObj)
    External (_SB_.ATKD.WMNB, MethodObj)

    Scope (\_SB.ATKD)
    {
        Method (ALSO, 0, NotSerialized)
        {
            Local0 = Buffer (0x14)
            {
                0x23, 0x00, 0x10, 0x00,
                0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00
            }
            Return (WMNB (Zero, 0x53545344, Local0))
        }

        Device (ALS0)
        {
            Name (_HID, "ASUS0001")
            Name (_UID, Zero)

            Method (_STA, 0, NotSerialized)
            {
                Return (0x0F)
            }

            Method (_INI, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    ALSO ()
                }
            }
        }
    }
}
