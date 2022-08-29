# Berechnungen ausführen auf einer GPU

Unter Verwendung von Metal GPUs identifizieren und auf diesen Berechnungen ausführen.

## Überblick

In diesem Beispiel wirst du die grundsätzlichen Schritte lernen, die du anwenden must in allen Metal Anwendungen.
Du wirst sehen wie du eine einfache in C geschriebenen Funktion in die Metal Shading Language (MSL) konvertierst, so dass du diese auf eine GPU laufen lassen kannst.
Du wirst eine GPU finden, eine MSL Funktion vorbereiten um diese diese mit einer erzeugten Pipeline auszuführen und Datenobjekte erzeugen auf die die GPU zugreifen kann.
Um die Pipeline mit deinen Daten auszuführen, erzeuge einen *Kommando Puffer*, schreibe Kommandos in diesen und schicke den Puffer an die Kommando-Verabeitungkette.
Metal sendet diese Kommandos an die GPU zur Ausführung.

## Schreiben einer GPU Funktion die Berechnungen ausführt.

Um zu zeigen wie GPU Programmerierung erfolgt wird diese Anwendung die korresspondierenden Elemente zweier Array mit einander addieren und das Ergebnis in ein drittes Array schreiben.
Listing 1 zeigt die Funktion, die diese Berechnung auf einer CPU ausführt und in C geschrieben ist.
Mit einer Schleife wird über deren Index ein Wert per Schleifendurchlauf berechnet.


**Listing 1** Array Addition, geschrieben in C

``` objective-c
void add_arrays(const float* inA,
                const float* inB,
                float* ergebnis,
                int length)
{
    for (int index = 0; index < length ; index++)
    {
        ergebnis[index] = inA[index] + inB[index];
    }
}
```

Jeder Wert wird unabhängig berechtet, so dass die Werte sicher nebenläufig / parallel / konkurrierend berechnet werden können.
Um die Berechnung mit der GPU ausführen zu können, musst du diese Funktion neu schreiben in der Metal Shading Language (MSL).
MSL ist eine Variante von C++, welche für GPU Programmierung erstellt wurde.
In Metal wird Code der auf einer GPU ausgeführt wird *shader* genannt, da historisch die ersten Anwendungen die Berechnung von Farben für 3D Grafiken waren.
Listing 2 zeigt einen *shader* in MSL welcher die selbe Berechnung ausführt wie in Listing 1.
Im Beispiel Projekt `MetalComputBasic` wird diese Funktion in der `add.metal` Datei definiert.
XCode compiliert aus allen `.metal` Dateien im Anwendungsziel und erzeugt die Standard-Metal-Bibliothek `default.metallib`, welche in deine Anwendung integriert wird. 
Du wirst später in diesem Beispiel sehen wie du diese Standard-Metal-Bibliothek lädst.


**Listing 2** Array Addition, geschrieben in MSL
``` metal
kernel void add_arrays(device const float* inA,
                       device const float* inB,
                       device float* ergebnis,
                       uint index [[thread_position_in_grid]])
{
    // Die for-Schleife ist ersetzt durch eine Sammlung von Threads, wo jeder dieser diese Funktion aufruft.
    ergebnis[index] = inA[index] + inB[index];
}
```

Listing 1 und Listing 2 sind ähnlich haben aber einige wichtige Unterschiede in der MSL Version aufzuweisen. Bei näherer Betrachtung des Listing 2 sind dies:

Zuerst, die Funktion fügt ein neues Schlüsselwort `kernel` hinzu, welches angibt, dass die Funktion:

- Eine *öffentliche GPU Funktion*. *Öffentliche* Funktionen sind die einziegen Funktionen, die deine Anwendung nutzen kann. Öffentliche Funktionen können jedoch nicht von anderen `shader` Funktionen aufgerufen werden.
- Eine *Berechnungs Function* (auch bekannt als `compute kernel`), welche eine parallele Ausführung durch ein n-dimensionales Gitter von Threads ermöglicht.

siehe auch [Using a Render Pipeline to Render Primitives](https://developer.apple.com/documentation/metal/using_a_render_pipeline_to_render_primitives) um andere Schlüsselwörter für Funktionen kennenzu leren und für die Verwendung von öffentlichen Grafikfunktionen.

Die `add_arrays` Funktion spezifiziert drei Zeiger-Argumente mit dem `device` Schlüsselwort, welches festlegt, dass diese Zeiger auf `device` Adressraum verweisen.
MSL definiert unterschiedliche unabhängige Adressräume für Speicher.
Wannimmer du einen Zeiger in MSL anlegst musst du mit einem Schlüsselwort angeben, welcher Adressraum verwendet wird.
Verwende den `device` Adressraum um ein persitenten Speicher anzugeben, von dem die GPU lesen und auf den die GPU schreiben kann.

Listing 2 entfernt die for-Schleife aus Listing 1, da die Funktion nun mit vielen Berechnungs-Threads aus dem Gitter aufgerufen wird.
Dieses Beispiel erzeugt ein 1-dimensionales Gitte von Threads, welches genau übereinstimmt mit den Array Dimensionen, so dass jedes Element in dem Array durch einen unterschiedlichen Thread berechnet wird.

Um den Index, welcher vorher in diener for-Schleife vorhanden war zu ersetzen, erhält die Funktion ein neues `index` argument, mit einem weiteren MSL Schlüsselwort `thread_position_in_grid` in C++ Attributesyntaxform benannt.
Dieses Schlüsselwort weist Metal an einen eindeutigen Index für jeden Thread zu erzeugen und diesen Index in diesem Argument zu speichern.
Da `add_arrays` ein eindimensionales Gitter verwendet ist der index als Ganzzahlenwert (integer) definiert.
Obwohl die Schleife entfernt wurde, nutzen Listing 1 und Listing 2 die selbe Zeile Quelltext um die beiden Zahlen miteinander zu addieren.
Wenn du ähnlichen Code von C oder C++ zu MSL konvertieren willst, ersetze die Schleifenlogik mit einem Gitter in genau dieser Art und Weise.

## Die GPU finden

In deiner Anwendung ist das [`MTLDevice`][MTLDevice] Objekt eine Abstraktions für die GPU; du benutzt dieses Objekt um mit der GPU zu kommunizieren.
Metal erzeugt ein `MTLDevice` für jede GPU.
Du erhälst für deine Standard-GPU ein Objekt durch Aufruf von  [`MTLCreateSystemDefaultDevice()`][MTLCreateSystemDefaultDevice].
In macOS, wo ein Mac mehrere GPUS haben kann, Metal wählt eine dieser GPUs als Standard aus und liefert für dieses ein `MTLDevice`-Objekt zurück.
In macOS stellt Metal über die API Möglichkeiten bereit um für alle GPUs ein solches Objekt zu erhalten. In diesem Beispiel jedoch nutzen wir dies Standard-GPU mit:

``` objective-c
id<MTLDevice> device = MTLCreateSystemDefaultDevice();
```

## Initialisiere Metal Objekte

Metal kapselt für andere mit der GPU in Verbindung stehende Teile, wie `compiled shader`, Speicherpuffer und Texturen als Objekte.
Um diese Objekte zu erhalten rufst du eine Methode direkt auf einem [`MTLDevice`][MTLDevice]-GPU-Objekt auf oder auf einem Objekt welches du vorher durch Aufruf einer Methoder auf dem [`MTLDevice`][MTLDevice]-GPU-Objekt erzeugt hast.
Jedes dieser Objekte unabhängig ob du es direkt oder indirekt erzeugt hast, kann nur mit der GPU kommunizieren über die du das [`MTLDevice`][MTLDevice]-GPU-Objekt erzeugt hast.
Anwendungen, welche mehrere GPUs verwenden wollen, müssen eine entsprechende Metal-Objekthierachie für jede einzelne GPU erzeugen. 
Die Beispielanwendung verwendet eine benutzerdefinierte Klasse `MetalAdder`, die sich um die Verwaltung der Objekte kümmert die mit der GPU kommunizieren.
Bei der Ersetllung der Klasse erzeugt diese Objekte und speichert eine Referenz auf diese in seinen Eigenschaften.
Die Anwendung erstelle eine Instanz des `MetalAdder` und übergibt diesem das [`MTLDevice`][MTLDevice]-GPU-Objekt um die nachfolgenden Objekte zu erzeugen. Die `MetalAdder`-Instanz behält dabei starke Referenzen zu den Metal Objekten bis die Ausführung beendet ist.

``` objective-c
MetalAdder* adder = [[MetalAdder alloc] initWithDevice:device];
```

In Metal können die aufwendigen Initialisierungsaufgaben einmalig durchgeführt und die Ergebnisse beibehalten werden umd diese ohne diesen Aufwand zu verwenden.
Du solltest solche aufwendigen Arbeiten in Performancekritischen Quelltext vermeiden.


## Erhalte die Referenz auf eine Metal Funktion

Das erste was der Initialisierer macht ist die Funktion zu laden un für die Ausführung auf der GPU vorzubereiten.
Wenn du deine Anwendung baust, compiliert XCode die `add_arrays` Funktion und fügt diese zu der Standard-Metal-Bibliothek `default.metallib` hinzu, welche in eine Anwendung integriert wird.
Du verwendetes `MTLLibrary` und `MTLFunction` Objekte um Informationen über die Metal Bibliothek und deren enthaltene Funktionen zu bekommen.
Um ein Objekt zu erhalten, welches die `add_arrays`-Funktion representiert, erzeugst du zunächst über [`MTLDevice`][MTLDevice] ein [`MTLLibrary`][MTLLibrary]-Objekt für die Standard-Metal-Bibliothek und anschließend über diese nach ein [`MTLFunction`][MTLFunction]-Objekt, welches deine `shader`-Funktion repräsentiert.

``` objective-c
- (instancetype) initWithDevice: (id<MTLDevice>) device {
    self = [super init];
    if (self)     {
        _mDevice = device;

        NSError* error = nil;

        // Load the shader files with a .metal file extension in the project

        id<MTLLibrary> defaultLibrary = [_mDevice newDefaultLibrary];
        if (defaultLibrary == nil) {
            NSLog(@"Failed to find the default library.");
            return nil;
        }

        id<MTLFunction> addFunction = [defaultLibrary newFunctionWithName:@"add_arrays"];
        if (addFunction == nil){
            NSLog(@"Failed to find the adder function.");
            return nil;
        }
```


## Bereite die Metal Pipeline vor

Das Funktion-Objekt ist ein Stellvertreter (Proxy) für die MSL-Funktion jedoch ist es kein ausführbarer Code.
Um die Funktion in einen auführbaren Code zu überführen erzeugst dur eine *Pipeline*.
Eine Pipeline spziefiziert die Schritte die GPU ausführen muss um die spezifische Aufgabe abzuschließen-
In Metal wird eine Pipeline durch ein *pipeline state*-Objekt repräsentiert.
Da diese Beispiel eine Berechnungsfunktion beinhaltet, erzeugt deine Anwendung auch ein entsprechendes [`MTLComputePipelineState`][MTLComputePipelineState] Objekt.

``` objective-c
_mAddFunctionPipelineStateObject = [_mDevice newComputePipelineStateWithFunction: addFunction error:&error];
```

Eine Berechnungs-Pipeline führt eine einzelne Berechnungsfunktion aus, optional ändert es die Eingabedaten vor dem Ausführen den Funktion und die Ausgabedaten nach dieser.

Wenn du ein *pipeline state*-Objekt erzeugst beendet das [`MTLDevice`][MTLDevice]-GPU-Objekt das compilieren der Funktion für diese spezifische GPU.
Dieses Beispiel erzeugt das *pipeline state*-Objekt synchron und liefert es direkt an die Anwendung zurück.
Da das Compilieren eines *pipeline state*-Objektes etwas dauern kann, vermeide in performancekritischen Anwendung die synchrone Erzeugung.


- Hinweis: Alle Objekte die von Metal zurück gegeben werden in dem Quelltext den du gesehen hast gibt Objekte zurück die konform zum jeweiligen Protokoll sind.
Metal definite die meisten GPU-spezifischen Objekte über Protokolle um von den unterliegenden Klassen zu abstrahieren, welche sehr unterschiedlich für verschiedenen GPUs sein können.
Metal definiert GPU-unabhängige Objekte mithilfe der Klassen.
Die Referenzdokumentation für jedes Metal Protokoll stellt klar, wo du eine eigene Implementierung des Protokoll in deiner Anwendung vornehmen kannst.

## Erzeuge eine Kommando Verarbeitungsschlange

Um eine Aufgabe zu der GPU zu senden benötigst du eine [`MTLCommandQueue`][MTLCommandQueue] Verarbeitungsschlage. Metal verwendet Verarbeitungsschlagen um den Ablauf der Kommandos zu planen.
Erzeuge die Verarbeitungsschlage durch Aufruf der Funktion auf [`MTLDevice`][MTLDevice].

``` objective-c
_mCommandQueue = [_mDevice newCommandQueue];
```


## Erzeuge einen Datenpuffer und lade die Daten

Nach dem Initialisiere der grundlegenden Metal Objekte lädst du die Daten die die GPU ausführen soll. Diese Aufgabe ist weniger Performancekritisch und doch sinnvoll möglichst früh nach dem Anwendungsstart zu realisieren.

Eine GPU kann einen eigenen, dezidierten, Speicher haben oder die GPU kann sich den Speicher mit dem Betriebssystem teilen.
Metal und der Kernel des Betriebssystem müssen zusätzliche Arbeit ausführen um deine Daten in den Speicher zu laden und dafür zu sorgen, dass die GPU Zugriff darauf hat. 
Metal abstrahiert dieses Speichermanagement durch *Resource* Objekte,  ([`MTLResource`][MTLResource]).
Eine Resource ist ein bereitgestellter Bereich von Speicher auf den die GPU Zugriff hat, wenn die Kommandos ausgeführt werden.
Mit dem [`MTLDevice`][MTLDevice] kannst du für diese GPU *Resource* Objekte erstellen.

Diese Beispiel Anwendung erzeugt drei Puffer und befüllt die ersten beiden mit zufälligen Daten.
Der dritte Puffer ist der, wo `add_arrays` seine Ergebnisse ablegen wird.

``` objective-c
_mBufferA = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
_mBufferB = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
_mBufferErgebnisse = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];

[self generateRandomFloatData:_mBufferA];
[self generateRandomFloatData:_mBufferB];
```

Die Ressourcen in diesem Beispiel sind [`MTLBuffer`][MTLBuffer] Objekte, welche den Speicher ohne eine Formatdefinition reservieren.
Metal verwaltet jeden Puffer als eine "interne (opaque)" Sammlung von Bytes.
Wie auch immer, du spezifizierst das Format wenn du den Puffer in deinem `shader` verwendest. 
Dies bedeutet, dass deine `shader` Funktion und deine Anwendung sich über das Format der Daten einig sein müssen, sowohl bei der Hinübertragung als auch bei der Rückübertragung. Dies kann auch über die Nutzung von C-Header erfolgen. In diesem Beispiel wird jedoch mit unstrukturierten Daten gearbeitet.

Wenn du deinen Puffer reservierst musst du eine `storage mode` angeben der Performanceeigenschaften angibt und ob die CPU und/oder GPU auf diesen Zugriff hat.
In diesem Beispiel verendest du geteilten Speicher mit Angabe von [`MTLResourceStorageModeShared`][MTLResourceStorageModeShared], auf welchen sowohl CPU als auch GPU Zugriff haben.

Um den Puffer mit zufälligen Daten zu füllen, schreibt die CPU über den Pointer auf den Pufferspeicher diese. Die `add_arrays` Funktion aus Listing 2 bestimmt die Argumente als Arrays vom Typ float, so dass die Puffer im gleichen Format bereit gestellt werden:

``` objective-c
- (void) generateRandomFloatData: (id<MTLBuffer>) buffer {
    float* dataPtr = buffer.contents;

    for (unsigned long index = 0; index < arrayLength; index++) {
        dataPtr[index] = (float)rand()/(float)(RAND_MAX);
    }
}
```


## Erzeuge einen Kommandopuffer
Üb die Kommando-Verarbeitungsschlange erzeugen wir einen Kommandopuffer.

``` objective-c
id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
```

## Erzeuge einen Kommando-Kodierer

Um Kommandos in die Kommando-Verarbeitungsschlage einzureichen verwendest du einen *command encoder* je nach der speziellen Art des Kommandos welches du schreibst.
Dieses Beipiel erzeugt einen Berechnungs-Kommando-Codierer, welches den *Berechnungsdurchlauf* kodiert.
Der Berechnungsdurchlauf hält eine Liste der Kommandos die die Berechnungs-Pipelines ausführen.
Jedes Berechnungs-Kommando veranlasst die CPU ein Gitter von Threads anzulegen, die auf der GPU ausgeführt werden. 

``` objective-c
id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
```

Um das Kommando zu schreiben wirst du eine Menge von Methodenaufrufen auf dem *encoder* durchführen.
Eine Methoden setzen Statusinformationen, wie das Pipline-Status-Objekt oder die Argumente die an die Pipeline übergeben werden.
Nachdem du diese Änderungen vorgenommen hast, schreibst du ein Kommando zur Ausführung der Pipeline.
Der *encoder* schreibt alle diese Statusparameter und die Kommandoparameter in den Kommandopuffer. 

![Command Encoding](Documentation/command_encoding.png)

## Setze den Pipeline Status und Argument Daten

Setze das Pipeline Status Objekt der Pipeline wo dur die Kommandos ausführen willst.
Dann setze die Daten für jedes Argument welches die Pipeline benötigt um diese an die `add_arrays` Funktion zu senden.
Für unser Beispiel bedeutet dies die Referenzen auf die drei Puffer bereitzustellen.
Metal weist automatisch die Indizies für die Puffer Argumente in der Reihenfolge zu, in welcher die Argumente in der Funktionsdeklaration im Listing 1 erscheinen, beginnende bei `0`.
Du musst diese Argumente mit den gleichen Indizies bereitstellen.

``` objective-c
[computeEncoder setComputePipelineState:_mAddFunctionPipelineStatusObjekt];
[computeEncoder setBuffer:_mBufferA offset:0 atIndex:0];
[computeEncoder setBuffer:_mBufferB offset:0 atIndex:1];
[computeEncoder setBuffer:_mBufferResult offset:0 atIndex:2];
```

Außerdem musst du einen Offset für jedes Argument angeben.
Ein Offset mit dem Wert `0` meint, dass das Kommando den Zugriff auf die Daten vom Beginn des Puffers an durchführt.
Wie auch immer, du kann einen Puffer nutzen um mehrere Argumente zu speichern und ein spezielles Offset für die Position von jedem Argument setzen.

Du kannst nicht festlegen die Daten für das *index* Argumene, da die `add_arrays` Funktion definiert diesen Wert als von der GPU bereitzustellen.

## Spezifiziere die Thread Anzahl und Organisation

Als nächstes triffst du die Entscheidung wieviele Threads erzeugt werden sollen und wie diese organisiert werden.
Metal kann 1-Dimensionale, 2-Dimensional oder 3-Dimensionale Gitter erstellen.
Die `add_arrays` Funktion verwendet ein 1-Dimensionales Array und daher erstellst du im Beispiel ein 1-Dimensionales Gitter mit der Größe der Daten - hier des Arrays - (`arrayLength` x 1 x 1), aus dem Metal dann die Indizies zwischen 0 und Datengröße-1 erzeugt.

``` objective-c
MTLSize gridSize = MTLSizeMake(arrayLength, 1, 1);
```

## Spezifiziere die Größe der Threadgruppe

Metal unterteilt das Gitter in kleinere Gridteile die Threadgruppe genannt werden.
Jede Threadgruppe führt die Berechnung gesondert durch.
Metal kann die Threadgruppen an unterschiedliche Verarbeitungselemente der GPU um die Verarbeitung zu beschleunigen. 
Du musst auch entscheiden wie groß die Threadgruppe für deine Kommandos sein soll.

``` objective-c
NSUInteger threadGroupSize = _mAddFunctionPipelineStateObjekt.maxTotalThreadsPerThreadgroup;
if (threadGroupSize > arrayLength) {
    threadGroupSize = arrayLength;
}
MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);
```

Die Anwendung fragt beim PipelineStateObjket die mximal mögliche Größe für die Threadgruppe an und kürzt diese, wenn deren Größe über der Größe der Daten liegt.
Die [`maxTotalThreadsPerThreadgroup`][maxTotalThreadsPerThreadgroup] Eigenschaft gibt die maximale Anzahl von Thread an die in einer Threadgruppe erlaubt sind; dies variert in Abhängigkeit von der Komplexität der Funktion welche zur Erzeugung des Pipeline Status Objekt verwendet wurde. 

## Kodiere die Berechnungs-Kommandos zur Ausführung der Threads

Letztlich kodiere die Kommando zum Versenden an das Threadgitter.

``` objective-c
[computeEncoder dispatchThreads:gridSize
          threadsPerThreadgroup:threadgroupSize];
```

Wenn die GPU dieses Anweisung ausführt verwendet sie den vorher gesetzten Status und die Parameter des Kommandos um die Threads zu versenden und die Berechnung auszuführen.

Du kannst diesen Schritten erneugt machen, um den Encode anzuweisen mehrere Berechnungs-Kommandos im Berechnungsdurchgang vorzusehen ohne jeden Schritt redundant zu wiederholen.
Zum Beispiel kannst du das Pipeline Status Objekt nur einmal setzen und dann die Argumente und das Kommando für jede Sammlung von zu verarbeitenden Puffern. 

## Beende den Berechnungsdurchlauf

Wenn du keine weiteren Kommandos mehr zu deinem Berechnungsdurchlauf hinzufügen willst, musst du den Kodierungsprozess beenden und den Berechnungsdurchlauf schließen.

``` objective-c
[computeEncoder endEncoding];
```

## Übergeben des Kommando-Puffer zur Ausführung deren Kommandos

Um die Kommandos auszuführen die im Kommando-Puffer ist der Kommando-Puffer an die Ausführungsschlange (Queue) zu übergeben.

``` objective-c
[commandBuffer commit];
```

Die Kommando Ausführungsschlange erzeugte den Kommandopuffer, so dass die Übergabe den Puffer immer in dieser Schlage plaziert.
Nach der Übergabe bereitet Metal asynchron die Kommandos für die Ausführung vor und plant die Ausführung der Kommandopuffer zur Ausführung durch die GPU.
Nachdem die GPU alle Kommandos im Kommandopuffer ausgeführt hat, markiert Metal den Kommandopuffer als komplett.

## Warte auf die Fertigstellung der Berechnung

Deine Anwendung kann andere Arbeit durchführen während die GPU die Kommandos ausführt.
Dieses Beispiel benötigt keine zusätzliche Arbeit so dass sie einfach wartet bis der Kommando-Puffer fertig ist.

``` objective-c
[commandBuffer waitUntilCompleted];
```

Alternativ zum Hinweis, wenn Metal die Verarbeitung aller Kommandos beednet hat, kannst du einen *completion* Handler am Kommandopuffer hinzufügen ([`addCompletedHandler`][addCompletedHandler]) oder du prüfst den Status des Kommandopuffer durch Auslesen der [`status`][status] Eigenschaft.

## Lesen des Ergebnis vom Puffer

Nach dem der Kommandopuffer abgearbeitet ist wird das GPU Berechnungsergebnis im Ausgabepuffer abgelegt und Metal führt alle notwendigen Schritte aus um sicherzustellen, dass die CPU diese sehen kann.
In einer realen Anwendung würdest du die Ergebnisse vom Puffer lesen und etwas mit diesen tun wie Anzeigen der Ergebnisse auf dem Bildschirm oder Schreiben der Ergebnisse in eine Datei.
Da die Berechnung lediglich durchgeführt wurde um zu zeigen wie der Prozess der Erstellung eine Metal Anwendung ist, liest dieses Beispiel die Werte aus dem Ausgabepuffer und testet, dass die CPU und die GPU die gleichen Ergebnisse berechnet haben. 

``` objective-c
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
```

----

[MTLDevice]: https://developer.apple.com/documentation/metal/mtldevice
[MTLCreateSystemDefaultDevice]: https://developer.apple.com/documentation/metal/1433401-mtlcreatesystemdefaultdevice
[MTLResource]: https://developer.apple.com/documentation/metal/mtlresource
[MTLBuffer]: https://developer.apple.com/documentation/metal/mtlbuffer
[MTLResourceStorageModeShared]: https://developer.apple.com/documentation/metal/mtlresourceoptions/mtlresourcestoragemodeshared
[MTLComputePipelineState]: https://developer.apple.com/documentation/metal/mtlcomputepipelinestate
[maxTotalThreadsPerThreadgroup]: https://developer.apple.com/documentation/metal/mtlcomputepipelinestate/1414927-maxtotalthreadsperthreadgroup
[status]: https://developer.apple.com/documentation/metal/mtlcommandbuffer/1443048-status
[addCompletedHandler]: https://developer.apple.com/documentation/metal/mtlcommandbuffer/1442997-addcompletedhandler
[MTLLibrary]: https://developer.apple.com/documentation/metal/mtllibrary
[MTLFunction]: https://developer.apple.com/documentation/metal/mtlfunction
[HelloTriangle]: https://developer.apple.com/documentation/metal

