#include <unity.h>
#include "../src/services/weight_filter.h"
#include "../src/services/gas_detector.h"

void test_median_filter_noise_spike() {
    WeightFilter filter(5);
    
    // Suite régulière à 8.0 kg avec pic de bruit abrupte à 15.0 kg
    filter.process(8.0f);
    filter.process(8.02f);
    filter.process(15.0f); // Pic parasite (choc / vibration)
    filter.process(8.01f);
    float val = filter.process(8.03f);

    // La valeur filtrée ne doit pas être déviée par le pic de 15 kg
    TEST_ASSERT_FLOAT_WITHIN(0.1f, 8.02f, val);
}

void test_bottle_replacement_detection() {
    WeightFilter filter(5);
    filter.process(0.5f); // Bouteille quasi vide
    filter.process(0.48f);

    float delta = 0.0f;
    // Remplacement par une bouteille pleine (saut de 12.0 kg)
    bool replaced = filter.checkBottleReplaced(12.48f, &delta);

    TEST_ASSERT_TRUE(replaced);
    TEST_ASSERT_FLOAT_WITHIN(0.2f, 12.0f, delta);
}

void test_gas_detector_hysteresis() {
    GasDetector detector(34, 10.0f);
    // Simule une lecture au-dessus du seuil (450 ppm > seuil 400)
    // Au début pas de fuite immédiate (temporisation anti-faux-positifs)
    bool leak1 = detector.isLeakDetected(450, 400);
    TEST_ASSERT_FALSE(leak1);
}

int main(int argc, char **argv) {
    UNITY_BEGIN();
    RUN_TEST(test_median_filter_noise_spike);
    RUN_TEST(test_bottle_replacement_detection);
    RUN_TEST(test_gas_detector_hysteresis);
    return UNITY_END();
}
