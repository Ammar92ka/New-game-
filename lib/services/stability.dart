class StabilitySystem {
  double economic = 60, social = 60, military = 55;
  double political = 65, religious = 70, regional = 50;
  double get total =>
      (economic + social + military + political + religious + regional) / 6;
  String get level {
    if (total >= 75) return 'مستقر';
    if (total >= 50) return 'متوتر';
    if (total >= 25) return 'مضطرب';
    return 'على حافة الانهيار';
  }
}
