/*
Siehe bitte im LICENSE Ordner für die Lizenzinformationen für dieses Beispiel.

Abstrakt:
Eine Anwendung die eine einfache Berechnung auf einen GPU ausführt.
*/

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "MetalAdder.h"

/**
 Diese Funktion ist das Beispiel geschrieben in C, welches in Metal reimplementiert wird.
 */
void add_arrays(const float* inA,
                const float* inB,
                float* result,
                int length) {
    NSLog(@"C-Schleife zur Addition zweier Arrays ausführen");
    for (int index = 0; index < length ; index++){
        result[index] = inA[index] + inB[index];
    }
}

/**
 Diese Funktion ist der Standard-Einspungspunkt in das C Programm
 */
int main(int argumentenAnzahl, const char * argargumentenVektor[]) {
    @autoreleasepool {
        NSLog(@"Ausführung gestartet");

        // Erzeuge eine Repräsentation der Standard-GPU
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();

        /*
         Erstelle eine angepasstes Objekt in dem der Metal Code gekapselt ist
         Initialisiere Objekte um mit der GPU zu kommunizieren
         */
        MetalAdder* adder = [[MetalAdder alloc] initWithDevice:device];
        
        // Erzeuge Puffer um die Daten vorzuhalten
        [adder prepareData];
        
        // Sende die Kommandos zur GPU um die Berechnung auszuführen.
        [adder sendComputeCommand];

        NSLog(@"Ausführung beendet");
    }
    return 0;
}
