#pragma once

#include <Arduino.h>

class WeightFilter {
public:
    explicit WeightFilter(size_t window_size = 9);
    ~WeightFilter();

    // Ajoute un échantillon brut en kg et renvoie la valeur filtrée
    float process(float raw_kg);

    // Détecte si un remplacement de bouteille a eu lieu
    bool checkBottleReplaced(float current_gross_kg, float* out_delta);

    void reset();

private:
    size_t _size;
    float* _buffer;
    size_t _index;
    size_t _count;
    float  _last_stable_weight;
    uint32_t _last_jump_time;
};
