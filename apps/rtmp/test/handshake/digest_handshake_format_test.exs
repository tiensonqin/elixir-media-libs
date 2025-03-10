defmodule Rtmp.Handshake.DigestHandshakeFormatTest do
  use ExUnit.Case, async: true

  alias Rtmp.Handshake.DigestHandshakeFormat, as: DigestHandshakeFormat

  @jwplayer_c0 <<0x03>>
  @jwplayer_c1 <<0x00, 0x12, 0x6C, 0xBB, 0x80, 0x00, 0x07, 0x02, 0x62, 0x3F, 0x16, 0x27, 0xC6,
                 0x1D, 0xAC, 0x34, 0x38, 0x46, 0xF2, 0xBC, 0x67, 0xCE, 0xED, 0xAC, 0xE3, 0x00,
                 0x0D, 0x73, 0x54, 0x46, 0x03, 0x95, 0xBA, 0xC3, 0x3B, 0xD7, 0xF5, 0xA4, 0x40,
                 0x5F, 0xA9, 0xD4, 0x7B, 0x0D, 0x91, 0xD9, 0x98, 0xBD, 0xAF, 0x21, 0xD0, 0x3D,
                 0xD4, 0xF0, 0x2F, 0x91, 0x47, 0xD3, 0xD4, 0x70, 0x5B, 0xD4, 0xD0, 0x67, 0x84,
                 0x64, 0x2B, 0x0D, 0x29, 0x66, 0xBD, 0x02, 0x09, 0x86, 0x8B, 0x64, 0x0D, 0x45,
                 0x01, 0xB0, 0xF8, 0xA7, 0xCA, 0x0E, 0xA2, 0x47, 0x6D, 0x2A, 0xEC, 0x94, 0xC0,
                 0xC8, 0x75, 0x1F, 0x44, 0x64, 0xB5, 0xA9, 0x18, 0x3C, 0x81, 0xCB, 0x86, 0xC0,
                 0x6D, 0xE6, 0x93, 0x9D, 0x86, 0x5C, 0x96, 0x43, 0xC7, 0xAC, 0x53, 0xF7, 0xB8,
                 0xF8, 0xBB, 0x5D, 0x73, 0xA7, 0x5A, 0x3A, 0x78, 0xF2, 0xAA, 0x88, 0x21, 0x2D,
                 0x78, 0x0F, 0x86, 0xC0, 0xCB, 0x61, 0x0D, 0x03, 0xCF, 0x54, 0x81, 0xC7, 0xAB,
                 0xD3, 0x76, 0xB6, 0x13, 0x38, 0x03, 0xCF, 0x53, 0x96, 0x41, 0xA3, 0xC9, 0xBC,
                 0x8B, 0x48, 0x2A, 0x58, 0xC9, 0xD3, 0xF3, 0x65, 0x96, 0x96, 0x0F, 0x1C, 0x8A,
                 0x88, 0xB3, 0x7C, 0xBB, 0x53, 0x40, 0x53, 0x47, 0xA2, 0xF8, 0xBE, 0x57, 0xE1,
                 0x8A, 0x3B, 0xC1, 0xF6, 0xDC, 0x97, 0x32, 0xFB, 0xEB, 0x4B, 0x06, 0x8E, 0x70,
                 0x68, 0x71, 0x84, 0x71, 0xDC, 0x6E, 0xAE, 0x54, 0xA5, 0xA7, 0xB7, 0x18, 0xF8,
                 0xDF, 0x89, 0xAB, 0x1F, 0x04, 0x64, 0xA3, 0xC1, 0x40, 0x82, 0xAB, 0x8D, 0x7F,
                 0x41, 0xAC, 0xDD, 0xC5, 0x2C, 0xE1, 0xE5, 0x45, 0x6F, 0x00, 0x72, 0xDF, 0x49,
                 0xE8, 0x7A, 0x09, 0x34, 0xA3, 0xCE, 0xB9, 0x06, 0xD4, 0x09, 0x45, 0x48, 0x07,
                 0x9B, 0x82, 0x9A, 0xAB, 0xFF, 0xF8, 0x86, 0x97, 0xC3, 0x90, 0xD1, 0x1D, 0x24,
                 0xE9, 0x81, 0x3B, 0x22, 0x5F, 0xB1, 0x01, 0x47, 0xB7, 0xB0, 0xA4, 0xC7, 0x79,
                 0x4C, 0xF7, 0xAE, 0x09, 0xDC, 0x34, 0xE9, 0x25, 0x2C, 0x7C, 0x46, 0x7B, 0x1B,
                 0x02, 0x7C, 0x07, 0x2A, 0xA2, 0x6C, 0xCE, 0xCC, 0x01, 0xFE, 0xA2, 0x02, 0xBB,
                 0xC1, 0x5D, 0x41, 0x21, 0xEA, 0xD7, 0x95, 0x9E, 0x26, 0xFE, 0x8D, 0xDB, 0xE8,
                 0x33, 0x9A, 0xF9, 0x0E, 0x1B, 0x00, 0xA7, 0x28, 0x84, 0x52, 0xD8, 0x30, 0xB5,
                 0x05, 0xBA, 0x87, 0xA9, 0x23, 0xE3, 0x46, 0xA5, 0x78, 0x10, 0x7A, 0xE5, 0xA9,
                 0xCC, 0xF1, 0xA5, 0xAE, 0x95, 0xE8, 0xD0, 0xE4, 0xC3, 0x43, 0xC4, 0x45, 0x9C,
                 0x4E, 0xCD, 0xA3, 0x8C, 0x52, 0xC8, 0x94, 0x6C, 0x86, 0xAB, 0x77, 0xA4, 0xDE,
                 0x39, 0x0F, 0x7B, 0x98, 0x0B, 0xD3, 0x94, 0xE4, 0x21, 0x40, 0xB5, 0x0D, 0xC1,
                 0x01, 0x94, 0x83, 0xA4, 0xC8, 0xF2, 0x27, 0xDA, 0x7F, 0x3F, 0x8A, 0xCE, 0xFA,
                 0x1D, 0x2C, 0xA2, 0x39, 0xA0, 0x8A, 0x73, 0x87, 0x87, 0x9F, 0x9F, 0xC8, 0xA2,
                 0xA4, 0x0A, 0x07, 0x88, 0x0D, 0x98, 0x8E, 0xD5, 0xCB, 0x1B, 0x2B, 0x00, 0x7A,
                 0xBB, 0xAF, 0xCE, 0x8A, 0x54, 0x52, 0x35, 0x37, 0x64, 0xC3, 0x6C, 0xBC, 0x07,
                 0xE5, 0x70, 0x13, 0x1B, 0x24, 0xA6, 0x9C, 0x48, 0xC4, 0xA4, 0x3F, 0x38, 0xD6,
                 0x22, 0x98, 0x89, 0x9C, 0x38, 0x03, 0xDC, 0x1E, 0x44, 0xCF, 0xE9, 0x6C, 0x5E,
                 0x48, 0x9A, 0x33, 0xC4, 0x9F, 0xB9, 0xC0, 0xBE, 0x79, 0x6D, 0x4C, 0x9E, 0x82,
                 0xAB, 0x61, 0x6A, 0xD3, 0x95, 0x1D, 0x56, 0xD2, 0x12, 0xBC, 0x3B, 0x15, 0x9C,
                 0x1E, 0x95, 0x0A, 0x36, 0x2C, 0x1E, 0xFD, 0xCB, 0x73, 0x46, 0x4E, 0x4C, 0xE5,
                 0x53, 0x63, 0xAE, 0xF1, 0x96, 0xE4, 0x76, 0x75, 0x28, 0x36, 0x94, 0xC9, 0xB6,
                 0x35, 0xB7, 0x5A, 0x32, 0xFA, 0xD1, 0x7C, 0xE5, 0x80, 0x0B, 0x33, 0x0C, 0xAA,
                 0x35, 0xBF, 0x96, 0xC0, 0xE5, 0x02, 0x55, 0x80, 0x97, 0x68, 0x6D, 0xF5, 0x52,
                 0xB3, 0x4B, 0x77, 0x0C, 0x1B, 0x8A, 0x55, 0xCD, 0xA0, 0x88, 0x84, 0xCE, 0x02,
                 0x6C, 0x99, 0x76, 0x91, 0x7A, 0x61, 0x79, 0x3A, 0xC1, 0x66, 0xCD, 0xE9, 0x36,
                 0x73, 0x2D, 0x41, 0xD2, 0x2B, 0x05, 0xC4, 0x88, 0x11, 0x74, 0x24, 0x83, 0x50,
                 0xED, 0x37, 0x5E, 0xC5, 0xC3, 0xFA, 0x84, 0x4D, 0x81, 0xF3, 0x2D, 0xF7, 0xF0,
                 0xFD, 0x08, 0xBC, 0x10, 0x9E, 0xE2, 0xEF, 0xDB, 0x4F, 0xCB, 0x6E, 0x9E, 0x14,
                 0x28, 0x39, 0x3A, 0x9A, 0xFA, 0x49, 0xF8, 0x63, 0x63, 0x8E, 0xA7, 0xE1, 0xB6,
                 0xDF, 0x37, 0xBD, 0xD7, 0xA6, 0xFD, 0xCF, 0x40, 0x40, 0x3D, 0x00, 0xB8, 0x5B,
                 0x44, 0x40, 0x82, 0x3E, 0x49, 0x9D, 0xCB, 0xF5, 0xAA, 0x30, 0x08, 0x04, 0x95,
                 0x39, 0x87, 0xB9, 0x1F, 0xB3, 0xB7, 0xFC, 0xE4, 0x72, 0x1E, 0xBC, 0x82, 0x7B,
                 0x16, 0x7F, 0x2C, 0xEA, 0x06, 0x9E, 0x5C, 0xB1, 0xB7, 0x34, 0x46, 0x62, 0x11,
                 0xF6, 0x1E, 0x4A, 0xCD, 0xEB, 0xA8, 0xED, 0x1A, 0xB6, 0x51, 0xC3, 0x68, 0xFB,
                 0x31, 0x2D, 0x9D, 0x84, 0x21, 0x9E, 0x96, 0xBF, 0xE5, 0x1B, 0x6B, 0x7B, 0x83,
                 0x47, 0xDD, 0x45, 0xFF, 0xC2, 0x70, 0x5D, 0xC3, 0xA5, 0x1D, 0x6B, 0x79, 0x27,
                 0xD1, 0x6D, 0x45, 0x47, 0x7B, 0x25, 0xAF, 0xED, 0x58, 0x1D, 0x8F, 0x2D, 0xCD,
                 0xEB, 0x25, 0x5E, 0x62, 0x68, 0x5F, 0x33, 0xF3, 0x50, 0x81, 0x0F, 0x5F, 0x95,
                 0x85, 0xF9, 0x99, 0x05, 0x1D, 0xFF, 0x6C, 0x9A, 0x9E, 0x3D, 0x3D, 0xD1, 0x1F,
                 0x53, 0x3A, 0x2E, 0x26, 0x2E, 0x6B, 0xDA, 0xB5, 0x41, 0x6D, 0x36, 0x45, 0x57,
                 0x1F, 0x0F, 0xEA, 0x24, 0x3E, 0xCE, 0x54, 0x79, 0x25, 0x8A, 0x9C, 0x27, 0xE8,
                 0x72, 0x27, 0x74, 0x4E, 0x05, 0x71, 0x01, 0x9F, 0x68, 0xDF, 0x44, 0xC7, 0x25,
                 0xC8, 0xBC, 0x95, 0x7F, 0x33, 0xEA, 0x08, 0xA9, 0xC4, 0x40, 0x15, 0x93, 0xAC,
                 0x69, 0x04, 0x8E, 0xD9, 0xB1, 0x98, 0x18, 0xFF, 0x16, 0x33, 0x61, 0x18, 0xB3,
                 0x08, 0xD0, 0x84, 0x8C, 0x49, 0xDC, 0x22, 0x2B, 0x9C, 0x09, 0xC5, 0x56, 0x97,
                 0xED, 0x80, 0xEB, 0x03, 0xBA, 0x66, 0x33, 0xDC, 0xF9, 0x7A, 0xEA, 0xFF, 0xC6,
                 0x27, 0xEF, 0xD6, 0x02, 0x4E, 0x1B, 0xA7, 0x2D, 0xFB, 0x58, 0xD7, 0xE8, 0x55,
                 0x48, 0x4B, 0x85, 0xB2, 0x0C, 0xEA, 0xAC, 0x66, 0x59, 0x12, 0x0E, 0xCC, 0x08,
                 0xB9, 0x1E, 0x08, 0xDB, 0x7B, 0x01, 0x60, 0x70, 0xB7, 0xD2, 0x49, 0x62, 0x5B,
                 0x4E, 0x45, 0x9E, 0xF4, 0xF4, 0x9C, 0x73, 0xBD, 0x20, 0xAF, 0xAF, 0xC2, 0xB9,
                 0xCB, 0x37, 0x10, 0x92, 0xED, 0x8A, 0x62, 0x11, 0x64, 0x66, 0xF4, 0xE2, 0x59,
                 0x7E, 0xAA, 0x24, 0x76, 0x64, 0x18, 0xAB, 0x34, 0x6D, 0x18, 0xC8, 0xC9, 0x1F,
                 0xBA, 0x62, 0x03, 0x01, 0xA9, 0xFB, 0xE3, 0xE5, 0x15, 0x06, 0x9D, 0xB0, 0x8F,
                 0x49, 0xA3, 0x4F, 0x91, 0x44, 0x3A, 0xD5, 0x25, 0xD0, 0x55, 0x52, 0x0F, 0x6B,
                 0x19, 0x30, 0xFB, 0x9B, 0x2A, 0x47, 0xEF, 0xBB, 0xDD, 0x36, 0x36, 0xAD, 0x66,
                 0x91, 0x6F, 0x88, 0xE9, 0xD2, 0xB4, 0x2D, 0xCD, 0x99, 0xD2, 0xB7, 0x0A, 0xEC,
                 0xA1, 0x6C, 0xBA, 0xDB, 0xF8, 0x6A, 0xD7, 0xED, 0x82, 0xD3, 0x72, 0x94, 0x4C,
                 0x57, 0x5F, 0x9A, 0xAA, 0xB4, 0x04, 0x92, 0x52, 0x36, 0xCA, 0x11, 0xEF, 0x81,
                 0x7A, 0x83, 0xA8, 0x87, 0x24, 0x6D, 0xE2, 0x10, 0x43, 0xD4, 0xE2, 0x9E, 0x25,
                 0x37, 0x83, 0xDC, 0x72, 0x7F, 0x63, 0x19, 0xF8, 0x2A, 0x84, 0x94, 0x6C, 0xF2,
                 0xF6, 0xAF, 0x4A, 0x53, 0x28, 0xD8, 0xB8, 0x5E, 0xD0, 0x1E, 0x45, 0x65, 0x43,
                 0xBD, 0x72, 0x4B, 0x55, 0x0A, 0x00, 0xAC, 0x39, 0x42, 0xDC, 0xEF, 0x9B, 0x25,
                 0x4E, 0x36, 0x61, 0x2F, 0x0D, 0xDB, 0x80, 0x0F, 0x8F, 0xE6, 0x1E, 0x0E, 0xD2,
                 0x7E, 0x12, 0x28, 0x56, 0xF5, 0x33, 0x8C, 0xA8, 0x6E, 0xFE, 0x63, 0x7F, 0xFB,
                 0x2E, 0xF7, 0xDE, 0x0E, 0x7C, 0xD9, 0x4C, 0xA4, 0x8D, 0xB7, 0x69, 0xEF, 0xAC,
                 0x6E, 0x74, 0x0C, 0x85, 0x75, 0xDC, 0x57, 0x80, 0xA0, 0x2E, 0xCA, 0xF4, 0x8A,
                 0x17, 0x0E, 0x21, 0x0E, 0x7C, 0x33, 0xA3, 0x8D, 0xFE, 0xB3, 0xDF, 0x5F, 0x7D,
                 0x8B, 0xE5, 0x84, 0x26, 0x1A, 0x3D, 0x1A, 0x76, 0x8A, 0x06, 0x0D, 0xB0, 0xB1,
                 0x95, 0xE9, 0x14, 0x61, 0x3A, 0xFB, 0xF6, 0xCE, 0x8B, 0x5D, 0x6F, 0x5A, 0x91,
                 0xC3, 0x32, 0x65, 0xB3, 0x1C, 0xFA, 0xFB, 0xBE, 0xD7, 0x2F, 0xE9, 0xD0, 0xA8,
                 0x24, 0x0A, 0x66, 0xC7, 0x60, 0xDF, 0xDC, 0x83, 0x21, 0xB2, 0x28, 0x2B, 0x94,
                 0xEE, 0x94, 0x6D, 0xA6, 0x21, 0x4E, 0x07, 0xD1, 0xE8, 0x6B, 0x1D, 0xE9, 0xD3,
                 0x00, 0xCA, 0xCA, 0x4C, 0xD2, 0x98, 0x7B, 0xD0, 0x37, 0xDE, 0x78, 0xFD, 0x84,
                 0x0E, 0xF1, 0x54, 0x6D, 0x2C, 0x26, 0x82, 0x53, 0x37, 0x01, 0x01, 0x23, 0x67,
                 0x4A, 0x78, 0xA6, 0x12, 0x49, 0x15, 0xB9, 0x25, 0x87, 0x06, 0x8E, 0xE7, 0xAF,
                 0x24, 0x41, 0x5E, 0x9E, 0x8D, 0x27, 0x93, 0xA6, 0x80, 0xAE, 0x72, 0xA0, 0x7C,
                 0x7B, 0x46, 0xD2, 0x1E, 0xCC, 0x4E, 0xB7, 0xB5, 0x17, 0x28, 0x73, 0x82, 0x33,
                 0x20, 0x8E, 0xFE, 0xE2, 0x39, 0x38, 0xE4, 0xE7, 0xF2, 0xA0, 0xA3, 0xB9, 0x76,
                 0x07, 0xC5, 0x36, 0x51, 0xE0, 0x57, 0x1A, 0x49, 0xF4, 0x61, 0xC6, 0x1F, 0x48,
                 0xF4, 0x70, 0x29, 0xA1, 0x2E, 0xFB, 0xBA, 0xFD, 0x3F, 0xB0, 0xD0, 0x76, 0xDB,
                 0x18, 0x7C, 0x63, 0xED, 0xA1, 0xE4, 0xB5, 0x50, 0xB5, 0x43, 0xA8, 0x5D, 0x49,
                 0xF2, 0xA4, 0x07, 0x96, 0xF6, 0x40, 0xFC, 0xEF, 0x9C, 0xC8, 0x2C, 0xE1, 0xD0,
                 0x70, 0xCD, 0x87, 0x94, 0x24, 0xEA, 0xFA, 0xF5, 0x56, 0x39, 0xEB, 0x22, 0xFA,
                 0x64, 0x54, 0x4B, 0x9D, 0x40, 0xB0, 0x83, 0x5B, 0xFA, 0xB5, 0x44, 0x8E, 0x6B,
                 0x48, 0x7E, 0xFA, 0x49, 0xEE, 0x9A, 0x82, 0x73, 0x7F, 0x25, 0xB1, 0x0E, 0x06,
                 0x43, 0xF4, 0xAA, 0xD4, 0x92, 0x72, 0x7F, 0xF2, 0xB5, 0x8F, 0x4B, 0xAC, 0x9B,
                 0x24, 0xAF, 0x28, 0xEE, 0x48, 0xD4, 0x39, 0x68, 0x8F, 0x59, 0x61, 0x2C, 0xAF,
                 0x93, 0x0B, 0xB2, 0x86, 0xA2, 0x3E, 0x21, 0xDB, 0x78, 0x7E, 0x9E, 0xDB, 0xCC,
                 0x46, 0xB9, 0x97, 0x49, 0x0C, 0x2C, 0x32, 0xAB, 0x3D, 0x39, 0xAB, 0x44, 0x7B,
                 0x7C, 0xAF, 0xF3, 0x32, 0x0D, 0xCC, 0x5B, 0xAD, 0x42, 0x57, 0xF2, 0x0D, 0x2F,
                 0x1B, 0xE3, 0xBF, 0xF2, 0xE3, 0xE7, 0xB4, 0x9A, 0x29, 0x37, 0x78, 0x4A, 0x11,
                 0xCD, 0x9F, 0xCC, 0x6E, 0xBB, 0xDC, 0x45, 0xB0, 0xDD, 0x0B, 0x83, 0xC0, 0xC0,
                 0x0D, 0x51, 0xBC, 0xBB, 0x75, 0x12, 0x6A, 0x85, 0xBA, 0x71, 0x80, 0x5D, 0x9B,
                 0x6C, 0xA4, 0x93, 0xF4, 0xAE, 0xBA, 0x28, 0x82, 0xD0, 0x56, 0x79, 0xDC, 0x39,
                 0x6D, 0xBC, 0x49, 0x62, 0x7D, 0x51, 0x60, 0xAA, 0x8D, 0x01, 0xD9, 0x15, 0xD0,
                 0x9C, 0xF9, 0x36, 0x5F, 0x82, 0x1F, 0x2A, 0xFC, 0xD6, 0xC1, 0x18, 0x87, 0xD8,
                 0x89, 0x49, 0x75, 0x29, 0xFE, 0xBC, 0x35, 0x37, 0x54, 0xEC, 0x0E, 0x41, 0x9A,
                 0xEC, 0x45, 0x37, 0xF7, 0x46, 0xBD, 0x17, 0x06, 0xB3, 0xF1, 0xC7, 0x70, 0x9A,
                 0x2B, 0x5A, 0x13, 0x3A, 0x58, 0xFC, 0xB3, 0x2B, 0xD0, 0x16, 0x07, 0x47, 0xC1,
                 0xD1, 0x4B, 0x7D, 0x77, 0x17, 0xD9, 0x34, 0x5A, 0x09, 0xD2, 0x8C, 0xFC, 0x6E,
                 0x39, 0x59>>

  test "Can validate JWPlayer handshake" do
    c0_and_c1 = @jwplayer_c0 <> @jwplayer_c1

    assert DigestHandshakeFormat.is_valid_format(c0_and_c1) == :yes
  end

  test "No unparsed binary after reading c0, c1, and c2" do
    c0_and_c1 = @jwplayer_c0 <> @jwplayer_c1

    state = DigestHandshakeFormat.new()
    {state, _} = DigestHandshakeFormat.process_bytes(state, c0_and_c1)
    {state, _} = DigestHandshakeFormat.process_bytes(state, @jwplayer_c1)

    assert state.unparsed_binary == <<>>
  end

  test "Can recognize its own c0 and c1 as valid" do
    {_, binary} = DigestHandshakeFormat.new() |> DigestHandshakeFormat.create_p0_and_p1_to_send()

    assert :yes == DigestHandshakeFormat.is_valid_format(binary)
  end
end
