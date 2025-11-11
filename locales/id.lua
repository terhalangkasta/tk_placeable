local Translations = {
    notify = {
        title = 'Penempat Prop',
        invalid_model = 'Model tidak valid.',
        create_failed = 'Gagal membuat prop.',
        prop_saved = 'Prop disimpan.',
        prop_removed = 'Prop dihapus.'
    },
    text = {
        unknown_prop = 'Tidak Dikenal',
        pickup = 'Ambil: %{label}'
    },
    prompts = {
        cancel = 'Batal',
        place = 'Pasang',
        rotate = 'Putar Kiri/Kanan',
        move_horizontal = 'Geser Kiri/Kanan',
        move_vertical = 'Geser Bawah/Atas',
        group = 'TK PLACEABLES',
        interaction_text = 'Interaksi   \nWaktu tersisa: %{minutes}:%{seconds}'
    },
    debug = {
        no_prop_match = 'Tidak ada prop yang cocok untuk hash: %{hash}',
        resource_stopping = 'Resource berhenti. Menghapus semua prop...'
    },
    logs = {
        invalid_coords = '[ERROR] Koordinat tidak valid diterima dari client: %{coords}',
        db_deleted = '[INFO] Prop dihapus dari database: model=%{model}, koordinat=%{coords}',
        loading = '^2[tk_placeable]^7 Memuat prop yang ditempatkan dari database...',
        load_failed = '^1[ERROR]^7 Gagal memuat prop dari database: %{error}',
        loaded_count = '^2[tk_placeable]^7 Memuat %{count} prop.',
        reload_complete = '[tk_placeable] Prop dari database telah dimuat ulang.'
    },
    command = {
        no_permission = 'Kamu tidak memiliki izin untuk menjalankan perintah ini.'
    }
}

if GetConvar('rsg_locale', 'en') == 'id' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang
    })
end
