#!/bin/bash

# Основная рабочая директория
WORK_DIR="/с/test"
mkdir -p "$WORK_DIR"

# 1. Создаем тестовые сервисы
echo "Создаем тестовые сервисы..."
MISC_DIR="$WORK_DIR/opt/misc"
mkdir -p "$MISC_DIR/service1" "$MISC_DIR/service2"

# Создаем исполняемые файлы-заглушки
cat > "$MISC_DIR/service1/foobar-daemon" <<EOF
#!/bin/bash
echo "Running service1 from \$(pwd)"
EOF

cat > "$MISC_DIR/service2/foobar-daemon" <<EOF
#!/bin/bash
echo "Running service2 from \$(pwd)"
EOF

chmod +x "$MISC_DIR"/service*/foobar-daemon

# 2. Создаем "юниты systemd"
SYSTEMD_DIR="$WORK_DIR/systemd_units"
mkdir -p "$SYSTEMD_DIR"

cat > "$SYSTEMD_DIR/foobar-service1.service" <<EOF
[Unit]
Description=Test Service 1

[Service]
WorkingDirectory=$MISC_DIR/service1
ExecStart=$MISC_DIR/service1/foobar-daemon
EOF

cat > "$SYSTEMD_DIR/foobar-service2.service" <<EOF
[Unit]
Description=Test Service 2

[Service]
WorkingDirectory=$MISC_DIR/service2
ExecStart=$MISC_DIR/service2/foobar-daemon
EOF

# 3. Функция для обработки юнита
process_unit() {
    local unit_file="$1"
    echo "Обрабатываем: $(basename "$unit_file")"
    
    # Извлекаем WorkingDirectory из файла
    working_dir=$(grep "WorkingDirectory=" "$unit_file" | cut -d= -f2)
    service_name=$(basename "$working_dir")
    
    # Новый путь
    new_dir="$WORK_DIR/srv/data/$service_name"
    mkdir -p "$new_dir"
    
    # Переносим файлы (используем Windows-совместимые пути)
    echo "Переносим $working_dir -> $new_dir"
    cp -r "${working_dir//\//\/}"/* "$new_dir/" 2>/dev/null
    
    # Обновляем файл юнита
    sed -i "s|WorkingDirectory=.*|WorkingDirectory=$(echo $new_dir | sed 's/\//\\\//g')|" "$unit_file"
    sed -i "s|ExecStart=.*/foobar-daemon|ExecStart=$new_dir/foobar-daemon|" "$unit_file"
    
    echo "Готово! Новые пути:"
    grep -E "WorkingDirectory|ExecStart" "$unit_file"
    echo "--------------------------------------"
}

# 4. Обрабатываем все "юниты"
for unit_file in "$SYSTEMD_DIR"/*.service; do
    process_unit "$unit_file"
done

# 5. Выводим результат
echo "Тест завершён. Содержимое папок:"
find "$WORK_DIR" -type f -exec ls -la {} \;