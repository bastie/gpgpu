/*
Siehe bitte im LICENSE Ordner für die Lizenzinformationen für dieses Beispiel.

Abstrakt:
Die Deklaration einer Klasse um alle Metal Objekte zu verwalten, die diese Anwendung erzeugt.
*/

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetalAdder : NSObject
- (instancetype) initWithDevice: (id<MTLDevice>) device;
- (void) prepareData;
- (void) sendComputeCommand;
@end

NS_ASSUME_NONNULL_END
