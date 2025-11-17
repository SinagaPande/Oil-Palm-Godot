# Instruksi Setup UI Manager

## Cara Menggunakan UI Manager

UI Manager adalah sistem UI terpusat yang menggabungkan semua elemen UI dalam 1 script dan 1 scene.

### Langkah Setup:

1. **Buka Level.tscn** (atau scene utama game Anda)

2. **Tambahkan UI_Manager ke scene:**
   - Klik kanan pada root node (biasanya "Node3D" atau "Level")
   - Pilih "Add Child Node"
   - Pilih "Instance Child Scene"
   - Pilih file `res://Scene/UI_Manager.tscn`
   - Atau drag & drop file `UI_Manager.tscn` dari FileSystem ke scene tree

3. **Pastikan UI_Manager berada di level yang sama dengan Player dan InventorySystem**

### Struktur UI Manager:

- **InventoryPanel** (kiri atas):
  - RipeLabel: Menampilkan buah matang yang dibawa dan diantar
  - UnripeLabel: Menampilkan poin buah mentah
  - HPLabel: Menampilkan HP player

- **InteractionLabel** (tengah bawah):
  - Menampilkan prompt interaksi dengan objek

### Catatan:

- UI_Manager akan otomatis mencari Player, InventorySystem, dan InteractionSystem
- Semua signal sudah terhubung otomatis
- UI lama (UI_Inventory.tscn) sudah dihapus dari Player.tscn
- InteractionSystem akan otomatis menggunakan UI_Manager jika ditemukan

### File yang Telah Diubah:

- ✅ `Script/UI_Manager.gd` - Script baru untuk semua UI
- ✅ `Scene/UI_Manager.tscn` - Scene baru untuk semua UI
- ✅ `Script/InteractionSystem.gd` - Diupdate untuk menggunakan UI_Manager
- ✅ `Scene/Player.tscn` - UI lama dihapus

### File Lama (Bisa Dihapus):

- `Script/UI_Inventory.gd` - Tidak digunakan lagi
- `Scene/UI_Inventory.tscn` - Tidak digunakan lagi

