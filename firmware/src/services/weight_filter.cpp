#include "weight_filter.h"
#include <algorithm>
#include <cmath>

WeightFilter::WeightFilter(size_t window_size)
    : _size(window_size), _index(0), _count(0), _last_stable_weight(0.0f), _last_jump_time(0) {
    _buffer = new float[_size];
    for (size_t i = 0; i < _size; ++i) {
        _buffer[i] = 0.0f;
    }
}

WeightFilter::~WeightFilter() {
    delete[] _buffer;
}

void WeightFilter::reset() {
    _index = 0;
    _count = 0;
    _last_stable_weight = 0.0f;
    for (size_t i = 0; i < _size; ++i) {
        _buffer[i] = 0.0f;
    }
}

float WeightFilter::process(float raw_kg) {
    // Élimination des valeurs aberrantes négatives extrêmes
    if (raw_kg < -5.0f || raw_kg > 100.0f) {
        return _last_stable_weight;
    }

    _buffer[_index] = raw_kg;
    _index = (_index + 1) % _size;
    if (_count < _size) {
        _count++;
    }

    // Calcul de la médiane glissante
    float sorted[_size];
    for (size_t i = 0; i < _count; ++i) {
        sorted[i] = _buffer[i];
    }
    std::sort(sorted, sorted + _count);

    float median = sorted[_count / 2];

    // Lissage léger passe-bas du résultat médian pour éviter les sauts discrets
    if (_count == 1) {
        _last_stable_weight = median;
    } else {
        _last_stable_weight = (_last_stable_weight * 0.7f) + (median * 0.3f);
    }

    // Arrondi au gramme près
    return std::round(_last_stable_weight * 1000.0f) / 1000.0f;
}

bool WeightFilter::checkBottleReplaced(float current_gross_kg, float* out_delta) {
    uint32_t now = millis();
    // Anti-rebond : un saut ne peut être détecté qu'une fois toutes les 60 secondes
    if (now - _last_jump_time < 60000) {
        return false;
    }

    float delta = current_gross_kg - _last_stable_weight;
    // Si augmentation soudaine > 8 kg (ex: passage de bouteille vide 13 kg à pleine 25.5 kg)
    if (delta >= 8.0f) {
        _last_jump_time = now;
        if (out_delta) *out_delta = delta;
        return true;
    }
    return false;
}
