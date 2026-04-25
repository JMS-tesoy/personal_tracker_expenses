class PaydayService {
  static bool isPrePayday(DateTime now) {
    return now.day == 14 || now.day == 29;
  }
}
