/*
Siehe bitte im LICENSE Ordner für die Lizenzinformationen für dieses Beispiel.

Abstrakt:
Die Implementation einer Klasse um alle Metal Objekte zu verwalten, die diese Anwendung erzeugt.
*/

#import "MetalAdder.h"

/// Die Anzahl der Ziffern, vom Typ float, in jedem Array.
const unsigned int arrayLength = 1 << 29;
/// Die Größe des Array in Bytes.
const unsigned int bufferSize = arrayLength * sizeof(float);

@implementation MetalAdder {
    /// Die Representation der GPU mit der du arbeitest
    id<MTLDevice> _mDevice;

    /// Die Berechnungs-Pipeline, erzeugt vom Berechnungs-Kernel in der .metal Shader Datei.
    id<MTLComputePipelineState> _mAddFunctionPipelineStateObject;

    /// Die Kommando-Verarbeitungsschlage, verwendet um die Kommandos an deine GPU zu senden.
    id<MTLCommandQueue> _mCommandQueue;

    /// Puffer um die Eingabedaten zu speichern.
    id<MTLBuffer> _mBufferA;
    /// Puffer um die Eingabedaten zu speichern.
    id<MTLBuffer> _mBufferB;
    /// Puffer um die Ergebnisdaten zu speichern.
    id<MTLBuffer> _mBufferErgebnisse;

}

- (instancetype) initWithDevice: (id<MTLDevice>) device {
    NSLog(@"initialisiere Metal mit den Device.");
    self = [super init];
    if (self) {
        _mDevice = device;

        NSError* error = nil;

        // Lade die Shader Dateien mit der .metal Dateiendung in dem Projekt, hier die Default Shader Datei "default.metallib" im Bundle
        id<MTLLibrary> defaultLibrary = [_mDevice newDefaultLibrary];
        if (nil == defaultLibrary) {
            NSLog(@"Fehler beim Auffinden der default Metal-Bibliothek.");
            return nil;
        }

        id<MTLFunction> addFunction = [defaultLibrary newFunctionWithName:@"add_arrays"];
        if (nil == addFunction) {
            NSLog(@"Fehler beim Auffinden der Funktion add_arrays in der Metal-Bibliothek.");
            return nil;
        }
        else {
            NSLog(@"Erfolgreiches Auffinden der Funktion add_arrays in der Metal-Bibliothek.");
        }

        // Erzeuge ein Statusobjekt für die Berechnungs-Pipeline.
        _mAddFunctionPipelineStateObject = [_mDevice newComputePipelineStateWithFunction: addFunction error:&error];
        if (nil == _mAddFunctionPipelineStateObject) {
            /*  Wenn die Metal API Prüfung aktiviert ist, kannst du mehr Informationen darüber erhalten, was fehlerhaft war. (Die Metal API Prüfung ist standardmäßig aktiviert, wenn im Debug-Modus unter XCode die Anwendung compiliert wurde.
             */
            NSLog(@"Fehler beim Erzeugen des Pipeline-Statusobjekt, Fehler: %@.", error);
            return nil;
        }

        _mCommandQueue = [_mDevice newCommandQueue];
        if (nil == _mCommandQueue) {
            NSLog(@"Fehler beim Auffinden der Kommando-Verarbeitungskette.");
            return nil;
        }
    }

    return self;
}

- (void) prepareData {
    NSLog(@"Vorbereiten der Berechnungsdaten");
    // Reservierung von drei Puffern um die initialen Berechnungsdaten und das Ergebnis zu speichern.
    _mBufferA = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    _mBufferB = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    _mBufferErgebnisse = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

    // Erzeuge die Berechnungsdaten
    [self generateRandomFloatData:_mBufferA];
    [self generateRandomFloatData:_mBufferB];
}

/// Erstelle ein Kommando für unsere Berechnung und sende diese für die Verarbeitung an die GPU.
/// Prüfe anschließend das Ergebnis der CPU Berechnung, gegen die GPU Berechnung.
- (void) sendComputeCommand {
    // Erzeuge einen Kommando-Puffer um die Kommandos zu speichern.
    id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
    if (nil != commandBuffer) {

        // Erzeugt für den Durchlauf einen Berechnungsencoder
        id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
        if (nil != computeEncoder) {
            // Ruft deine Methode zum ... auf und übergibt dieser deinen Berechnungsencoder.
            [self encodeAddCommand:computeEncoder];

            // Markiert das Ende im Berechungsencoder.
            [computeEncoder endEncoding];

            // Führt den Kommandopuffer aus.
            [commandBuffer commit];

            // Normalerweise willst du vielleicht andere Aufgaben erledigen, während die GPU arbeitet. Aber in diesem Beispiel warten wir bist die Berechnung abgeschlossen ist.
            [commandBuffer waitUntilCompleted];

            // Prüfe, ob die Ergebnisse der CPU-Berechnung mit denen der GPU-Berechnung übereinstimmen
            [self verifyResults];
        }
        else {
            NSLog(@"Fehler beim Erzeugen des Berechnungsencoder.");
        }
    }
    else {
        NSLog(@"Fehler beim Erzeugen des Kommandopuffers.");
    }
}

- (void)encodeAddCommand:(id<MTLComputeCommandEncoder>)computeEncoder {

    // Erstelle das Pipeline-Statusobjekt und seine Parameter
    [computeEncoder setComputePipelineState:_mAddFunctionPipelineStateObject];
    [computeEncoder setBuffer:_mBufferA offset:0 atIndex:0];
    [computeEncoder setBuffer:_mBufferB offset:0 atIndex:1];
    [computeEncoder setBuffer:_mBufferErgebnisse offset:0 atIndex:2];

    MTLSize gridSize = MTLSizeMake(arrayLength, 1, 1);

    // Berechne die Größe der Threadgruppe.
    NSUInteger threadGroupSize = _mAddFunctionPipelineStateObject.maxTotalThreadsPerThreadgroup;
    NSLog(@"Größe der Threadgruppe ist %lu.",threadGroupSize);
    
    // Die Größe der Threadgruppe muss nicht mehr als die maximale Anzahl der Berechnungen sein.
    if (threadGroupSize > arrayLength) {
        threadGroupSize = arrayLength;
        NSLog(@"Neue Größe der Threadgruppe ist %lu.", threadGroupSize);
    }
    // Verpacke die Größe der Threadgruppe passend für dass Berechnungskommando.
    MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);

    // Setze die Größe der Grid und der Threadgruppe beim Berechnungskommando.
    [computeEncoder dispatchThreads:gridSize
              threadsPerThreadgroup:threadgroupSize];
}

/// Erzeuge zufällige Daten vom Typ float und speichere diese im übergebenen Puffer
- (void) generateRandomFloatData: (id<MTLBuffer>) buffer {
    NSLog(@"Erzeuge zufällige Daten und speichere %i Einträge diese im übergebenden Puffer.", arrayLength);
    float* dataPtr = buffer.contents;

    for (unsigned long index = 0; index < arrayLength; index++) {
        dataPtr[index] = (float)rand()/(float)(RAND_MAX);
    }
}
/// Prüfe die Ergebnisse der Berechnung
- (void) verifyResults {
    NSLog(@"Prüfe die Berechnung.");
    float* a = _mBufferA.contents;
    float* b = _mBufferB.contents;
    float* ergebnis = _mBufferErgebnisse.contents;

    for (unsigned long index = 0; index < arrayLength; index++) {
        if (ergebnis[index] != (a[index] + b[index])) {
            NSLog(@"Berechnungsfehler: index=%lu ergebnis=%g vs %g=a+b",
                   index, ergebnis[index], a[index] + b[index]);
            assert(ergebnis[index] == (a[index] + b[index]));
        }
    }
    NSLog(@"Die berechneten Ergebnisse entsprechen den Erwartungen.");
}
@end
