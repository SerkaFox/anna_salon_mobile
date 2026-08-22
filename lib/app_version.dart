const appVersionName = '0.1.31';
const appVersionBuild = 32;

const appChangeLog = <AppChangeLogEntry>[
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
