const appVersionName = '0.1.36';
const appVersionBuild = 37;

const appChangeLog = <AppChangeLogEntry>[
  AppChangeLogEntry(
    version: '0.1.36',
    build: 37,
    changesRu: [
      'Системный установщик возвращает пользователя прямо в приложение.',
    ],
    changesEs: [
      'El instalador del sistema devuelve al usuario directamente a la aplicacion.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.35',
    build: 36,
    changesRu: [
      'Перезапуск после обновления адаптирован для ограничений Android 14–16.',
    ],
    changesEs: [
      'Reinicio tras actualizar adaptado a las restricciones de Android 14–16.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.34',
    build: 35,
    changesRu: [
      'Установка продолжается автоматически после выдачи разрешения.',
      'Приложение повторно запускается после успешного обновления.',
    ],
    changesEs: [
      'La instalacion continua automaticamente despues del permiso.',
      'La aplicacion vuelve a abrirse despues de actualizarse.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.33',
    build: 34,
    changesRu: [
      'Шкала календаря продлена до 21:00.',
    ],
    changesEs: [
      'La escala del calendario se amplio hasta las 21:00.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.32',
    build: 33,
    changesRu: [
      'Автоматическая проверка обновлений при запуске.',
      'Защищённое скачивание APK с проверкой SHA-256.',
      'Установка обновлений и ручная проверка из настроек.',
    ],
    changesEs: [
      'Comprobacion automatica de actualizaciones al iniciar.',
      'Descarga protegida del APK con verificacion SHA-256.',
      'Instalacion y comprobacion manual desde los ajustes.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.31',
    build: 32,
    changesRu: [
      'Поиск клиентов, услуг и сотрудников при добавлении в лист ожидания.',
      'Текущая версия и история изменений добавлены в настройки.',
    ],
    changesEs: [
      'Busqueda de clientes, servicios y empleados al anadir a la lista de espera.',
      'Version actual e historial de cambios en los ajustes.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.30',
    build: 31,
    changesRu: [
      'Анна может создавать записи вручную вне рабочего графика.',
      'Добавление в лист ожидания из приложения.',
      'Дата или период ожидания, желаемое время и комментарий.',
    ],
    changesEs: [
      'Reservas manuales fuera del horario de trabajo.',
      'Alta en la lista de espera desde la aplicacion.',
      'Fecha o periodo, horario deseado y comentario.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.29',
    build: 30,
    changesRu: [
      'Красная линия текущего времени в календаре.',
      'Чёрные деления календаря по 15 минут.',
      'Поиск услуг, отпускные сотрудников и серый цвет оплаченных заказов.',
    ],
    changesEs: [
      'Linea roja de la hora actual en el calendario.',
      'Divisiones negras cada 15 minutos.',
      'Busqueda de servicios, vacaciones y reservas pagadas en gris.',
    ],
  ),
];

class AppChangeLogEntry {
  const AppChangeLogEntry({
    required this.version,
    required this.build,
    required this.changesRu,
    required this.changesEs,
  });

  final String version;
  final int build;
  final List<String> changesRu;
  final List<String> changesEs;
}
