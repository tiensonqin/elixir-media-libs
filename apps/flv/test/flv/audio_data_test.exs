defmodule Flv.AudioDataTest do
  use ExUnit.Case, async: true

  test "Can parse audio aac sequence header" do
    binary = <<0xAF, 0x00, 0x12, 0x10, 0x56, 0xE2>>

    assert {:ok,
            %Flv.AudioData{
              format: :aac,
              sample_rate_in_khz: 44,
              sample_size_in_bits: 16,
              channel_type: :stereo,
              aac_packet_type: :sequence_header,
              data: <<0x12, 0x10, 0x56, 0xE2>>
            }} = Flv.AudioData.parse(binary)
  end

  test "Can parse raw aac packet" do
    binary =
      Base.decode16!(
        "AF01270C54FA06C301B0C068301A0B0A86E1A0C05830260D0604C180B0604C281210828120A04828113FB187B1640590B2C868B21F0083FFB139156216BD06F65473FA4F6195B38717ED536BF3D1FF214F1E111D2C20ABCE794C77125E98675A85D62205EEFB3DDF1EF306A738F25193B4D3EB48FCF866C122521608CF77D1A6B956F316FCBD429979FCFE8E5A27F47C485E6CD3BF65FEF114DB9AB016C7CBFE877DF8E4CE877E9941704C18AF9137B68A2A45182615E46C1B5B09C651B35DF643FD3A864A5F8A1ACE7E8E56FCC19242CA9CE528E22FBD3ACEDA1188203BCE21DB30129846779DFD5F56FCD9746CE79720377BEE3FC12F47BEEDF9EE8BEBCE8F24E97C5A559DE3FB459D9C30508E63CC40CFD957DCCCFF4007414370EE5CC4CA63668EA09EB98898731E3741E6C6AAC25254539461ADBB45A2026F548A16CCA5A9488BFE9AEE5D63952B656961A484678834280A06024180909848360A15422140904C221308B0022103D90E88428B2CB210859C061E89374ACF13ECF96FA2F7D37B72F4BED5263D227F22FB496E7EAF55FA9EA1FD85BD0F249F4427FB5B2E5C6F8DFF2CDE4B49B3857F366728AA63534F5E5D7D30E4B993EDCD12D2F887DD3187D898FDBB73891971D212E952060081724B48002C05A0B0016018818823C0"
      )

    expected_data =
      Base.decode16!(
        "270C54FA06C301B0C068301A0B0A86E1A0C05830260D0604C180B0604C281210828120A04828113FB187B1640590B2C868B21F0083FFB139156216BD06F65473FA4F6195B38717ED536BF3D1FF214F1E111D2C20ABCE794C77125E98675A85D62205EEFB3DDF1EF306A738F25193B4D3EB48FCF866C122521608CF77D1A6B956F316FCBD429979FCFE8E5A27F47C485E6CD3BF65FEF114DB9AB016C7CBFE877DF8E4CE877E9941704C18AF9137B68A2A45182615E46C1B5B09C651B35DF643FD3A864A5F8A1ACE7E8E56FCC19242CA9CE528E22FBD3ACEDA1188203BCE21DB30129846779DFD5F56FCD9746CE79720377BEE3FC12F47BEEDF9EE8BEBCE8F24E97C5A559DE3FB459D9C30508E63CC40CFD957DCCCFF4007414370EE5CC4CA63668EA09EB98898731E3741E6C6AAC25254539461ADBB45A2026F548A16CCA5A9488BFE9AEE5D63952B656961A484678834280A06024180909848360A15422140904C221308B0022103D90E88428B2CB210859C061E89374ACF13ECF96FA2F7D37B72F4BED5263D227F22FB496E7EAF55FA9EA1FD85BD0F249F4427FB5B2E5C6F8DFF2CDE4B49B3857F366728AA63534F5E5D7D30E4B993EDCD12D2F887DD3187D898FDBB73891971D212E952060081724B48002C05A0B0016018818823C0"
      )

    assert {:ok,
            %Flv.AudioData{
              format: :aac,
              sample_rate_in_khz: 44,
              sample_size_in_bits: 16,
              channel_type: :stereo,
              aac_packet_type: :raw_data,
              data: ^expected_data
            }} = Flv.AudioData.parse(binary)
  end
end
