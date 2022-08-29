/*
Siehe bitte im LICENSE Ordner für die Lizenzinformationen für dieses Beispiel.

Abstrakt:
Ein Shader der zwei Arrays vom Typ float addiert.
*/

#include <metal_stdlib>
using namespace metal;
/// This is a Metal Shading Language (MSL) function equivalent to the add_arrays() C function, used to perform the calculation on a GPU.
kernel void add_arrays(device const float* inA,
                       device const float* inB,
                       device float* ergebnis,
                       uint index [[thread_position_in_grid]]) {
    // Die for-Schleife ist ersetzt durch eine Sammlung von Threads, wo jeder dieser diese Funktion aufruft.
    ergebnis[index] = inA[index] + inB[index];
}
