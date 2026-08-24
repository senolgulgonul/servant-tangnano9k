# Servant (SERV) on Tang Nano 9K

Version 0.5.0, 2026-08-24

olofk/serv projesindeki Servant referans SoC'unun Sipeed Tang Nano 9K
(Gowin GW1NR-LV9QN88PC6/I5, GW1N-9C) portu. Upstream'de hicbir Gowin hedefi
yok, buradaki her sey yeni.

Cekirdek kartin 27 MHz osilatoruyle dogrudan calisiyor, PLL yok.

Bu arsiv kendi kendine yeterli. serv reposunu ayrica klonlaman gerekmiyor,
gereken 26 Verilog dosyasinin tamami `src/` icinde.

## Icerik

```
servant_tn9k/
  src/                    26 Verilog dosyasi + tangnano9k.cst
  blinky.hex              ilk deneme icin
  zephyr_hello.hex        sonraki adim icin
  LICENSE_serv            SERV'in ISC lisansi
  OKU.md                  bu dosya
```

`src/` icinde tam olarak sentezlenmesi gereken dosyalar var, fazlasi yok.
serv reposundaki `serv_synth_wrapper.v` (ayri bir sentez sarmalayicisi, top ile
cakisir), `servant_ram_quartus.sv` (Quartus'a ozel) ve `serv_debug.v` bilerek
disarida birakildi.

## 1. Yeni proje

File > New > FPGA Design Project.

- Proje adi: `servant_tn9k`
- Konum: nereye istersen
- Series: **GW1NR**
- Device: **GW1NR-9**
- Device Version: **C**
- Package: **QFN88P**
- Speed: **C6/I5**

Part numarasi `GW1NR-LV9QN88PC6/I5` gorunmeli.

Device Version'i bos birakirsan bitstream yine uretilir, karta yine yuklenir,
ama kart hicbir sey yapmaz ve hicbir hata mesaji cikmaz. Karttaki cip C
revizyonu.

## 2. Dosyalari ekle

Add Files, `src/` klasorune gir, **hepsini birden sec** (Ctrl+A), ekle.
Kopyalamayi sorarsa tercihine kalmis, No dersen kaynaklar tek yerde kalir.

27 dosya eklenmis olmali: 26 Verilog ve 1 cst.

## 3. Top modul

Project > Configuration > General > Top Module: `servant_tangnano9k`

Genelde otomatik dogru secer, yine de kontrol et.

## 4. Bellek imajini bagla

`src/servant_tangnano9k.v` icindeki su satiri ac:

```verilog
  #(parameter memfile = "blinky.hex",
```

ve `blinky.hex` dosyasinin **mutlak yolunu** yaz, ters bolu degil duz bolu ile:

```verilog
  #(parameter memfile = "D:/docs/ostim/digital/gowin/serv_tn9k/blinky.hex",
```

Bu adimi atlarsan olacak sey su: GowinSynthesis `impl/gwsynthesis` icinden
calisiyor, goreli `"blinky.hex"` cozulmuyor, RAM sifir dolu kaliyor, cekirdek
bosluk calistiriyor, LED hic yanmiyor. Hicbir hata mesaji cikmiyor.

Sentez log'unda `Preloading` satirini goruyorsan yol dogru demektir. Bu tek
satir, ileride bir sey calismazsa bakacagin ilk yer.

## 5. Sentez ve PnR

Process panelinde Synthesize, sonra Place & Route.
Cikti: `impl\pnr\servant_tn9k.fs`

## 6. Yukleme

Programmer, cihaz otomatik bulunmali.

- Denemeler icin: **SRAM Program**, ucucu ama hizli
- Kalici icin: **embFlash Erase, Program**

Tang Nano 9K'da **embFlash Erase, Program, Verify** calismaz, Verify'siz olani
sec. openFPGALoader tercih edersen:

```
openFPGALoader -b tangnano9k impl\pnr\servant_tn9k.fs        # SRAM
openFPGALoader -b tangnano9k -f impl\pnr\servant_tn9k.fs     # flash
```

## Beklenen sonuc

Karttaki LED0 (pin 10) yanip soner. Periyot 27 MHz'de gozle rahat secilir.

Yanmazsa sirasiyla kontrol et: sentez log'unda `Preloading` var mi, Device
Version C secili mi, `.fs` gercekten yuklendi mi.

## Pin atamalari

| Sinyal | Pin | Not |
| --- | --- | --- |
| `i_clk` | 52 | 27 MHz osilator |
| `i_rst_n` | 4 | S1 butonu, aktif dusuk |
| `o_uart_tx` | 17 | BL702 uzerinden USB seri porta |
| `o_led` | 10 | LED0, aktif dusuk |

Sadece tek LED var, cunku servant'in tek cikis biti (`q`) var. Kartin
LED4 ve LED5'i pin 15 ve 16'da, o pinler Bank 3'te ve o bank PSRAM tarafindan
1.8V'a kilitli. Oraya LVCMOS33 dayatmak CT1136 hatasi veriyor. Tek LED
kullanarak o bank'a hic dokunmuyoruz.

## Zephyr'e gecerken: baud 97200

Servant'in Zephyr UART'i bit-bang ve 32 MHz cekirdek saatinde 115200 baud'a
gore ayarli. 27 MHz'de hiz ayni oranda olceklenir:

```
115200 * 27 / 32 = 97200 baud
```

Terminali 97200'e ayarla. PuTTY ve Tabby serbest baud kabul ediyor.
`blinky.hex` UART kullanmiyor, o asamada onemi yok.

Standart bir hiz istersen 27 MHz'den tam 32 MHz uretilemiyor: 32/27 zaten
sadelesmis durumda, IDIV_SEL=26 gerekir ve bu 1 MHz faz dedektoru demek,
yasal alt sinir 3 MHz. En yakin gecerli oran 6/5, yani 32.4 MHz, bu da 116640
baud eder (%1.25 hata). Bunun rPLL kodu ayri duruyor, istersen eklerim.

## Dogrulanmis olan

yosys `synth_gowin` ile kontrol edildi:

- 8 kiB ana RAM BSRAM'e oturuyor, dort blok, lojige dagilmiyor. Portun en
  riskli noktasi buydu: upstream'de Quartus icin ayri bir
  `servant_ram_quartus.sv` yazilmis olmasinin sebebi byte-enable cikariminin
  cogu aracta kirilgan olmasi.
- SERV register file LUTRAM'e oturuyor, 36 RAM16SDP4.
- Latch yok, sentez hatasi yok.

Tum SoC icin hucre sayimi: 722 LUT, 87 ALU, 261 flip-flop, 36 RAM16SDP4,
4 BSRAM.

Bunlar SoC rakamlari, cekirdek rakami degil. Upstream cikplak minimal cekirdek
icin iCE40'ta 198 LUT / 164 FF veriyor. Birebir kiyas istersen
`serv_synth_wrapper`'i tek basina sentezlemek gerekir.

## Sonraki adimlar

1. 27 MHz'de blinky. RAM init'ini, reset'i ve GPIO'yu dogrular.
2. `zephyr_hello.hex`, memsize 8192, terminal 97200 baud.
3. memsize 32768, dining philosophers imaji.
4. fusesoc hedefi olarak sarip upstream'e PR.
