//
//  NSObject+MLNKVO.m
//  MLN
//
//  Created by Dai Dongpeng on 2020/4/29.
//

#import "NSObject+MLNKVO.h"
#import "MLNKVOObserver.h"
#import "MLNExtScope.h"
#import "NSObject+MLNDealloctor.h"
#import "MLNArrayObserver.h"

#define kArrayKVOPlaceHolder @"kArrayKVOPlaceHolder"

@import ObjectiveC;

@implementation NSObject (MLNKVO)

#pragma mark - Public
- (NSObject * _Nonnull (^)(NSString * _Nonnull, MLNKVOBlock _Nonnull))mln_watch {
        @weakify(self);
        return ^(NSString *keyPath, MLNKVOBlock block){
            @strongify(self);
            if (self && block) {
                [self mln_observeProperty:keyPath withBlock:^(id  _Nonnull observer, id  _Nonnull object, id  _Nonnull oldValue, id  _Nonnull newValue, NSDictionary<NSKeyValueChangeKey,id> * _Nonnull change) {
                    block(oldValue, newValue);
                }];

            }
            return self;
        };
}

- (void)mln_observeProperty:(NSString *)keyPath withBlock:(MLNBlockChange)observationBlock {
    [self mln_observeObject:self property:keyPath withBlock:observationBlock];
}


- (void)mln_observeObject:(id)object property:(NSString *)keyPath withBlock:(MLNBlockChange)observationBlock {
    MLNObserver *observer = nil;
    @autoreleasepool {
        observer = [object mln_observerForKeyPath:keyPath owner:self];
    }
    __weak __typeof(self)weakSelf = self;
    [observer addObservationBlock:^(id  _Nonnull observer, id  _Nonnull object, id  _Nonnull oldValue, id  _Nonnull newValue, NSDictionary<NSKeyValueChangeKey,id> * _Nonnull change) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        observationBlock(strongSelf, object, oldValue, newValue, change);
    }];
}

- (void)mln_observeObject:(id)object properties:(NSArray <NSString *> *)keyPaths withBlock:(MLNBlockChangeMany)observationBlock {
    for (NSString *keyPath in keyPaths) {
        [self mln_observeObject:object property:keyPath withBlock:^(id  _Nonnull observer, id  _Nonnull object, id  _Nonnull oldValue, id  _Nonnull newValue, NSDictionary<NSKeyValueChangeKey,id> * _Nonnull change) {
            observationBlock(observer, object, keyPath, oldValue, newValue, change);
        }];
    }
}

- (MLNObserver *)mln_observerForKeyPath:(NSString *)keyPath owner:(id)owner {
    MLNObserver *observer = nil;
    NSMutableDictionary *observers = [self mln_keyPathBlockObserversCreateIfNeeded:YES];
    NSMutableSet *observersForKeyPath = [observers objectForKey:keyPath];
    if (!observersForKeyPath) {
        observersForKeyPath = [NSMutableSet set];
        [observers setObject:observersForKeyPath forKey:keyPath];
    } else {
        for (MLNObserver *existingObserver in observersForKeyPath) {
            if (existingObserver.owner == owner) {
                observer = existingObserver;
                break;
            }
        }
    }
    if (!observer) {
        if ([keyPath isEqualToString:kArrayKVOPlaceHolder] && [self isKindOfClass:[NSMutableArray class]]) {
            observer = [[MLNArrayObserver alloc] initWithTarget:self keyPath:kArrayKVOPlaceHolder owner:owner];
        } else {
            observer = [[MLNObserver alloc] initWithTarget:self keyPath:keyPath owner:owner];;
        }
        [observersForKeyPath addObject:observer];
        [observer attach];
        
        if (owner != self) {
            __weak MLNObserver *weakObserver = observer;
            [owner mln_addDeallocationCallback:^(id  _Nonnull receiver) {
                [weakObserver.target mln_removeObervationsForOwner:receiver keyPath:keyPath];
            }];
        }
    }
    return observer;
}

- (NSMutableDictionary *)mln_keyPathBlockObserversCreateIfNeeded:(BOOL)shouldCreate {
    @synchronized (self) {
        NSMutableDictionary *keyPathObservers = objc_getAssociatedObject(self, _cmd);
        if (!keyPathObservers && shouldCreate) {
            keyPathObservers = [NSMutableDictionary dictionary];
            objc_setAssociatedObject(self, _cmd, keyPathObservers, OBJC_ASSOCIATION_RETAIN);
            [self mln_addDeallocationCallback:^(id  _Nonnull receiver) {
                [receiver mln_removeAllObservations];
            }];
        }
        return keyPathObservers;
    }
}

- (void)mln_removeAllObservations {
    NSMutableDictionary *keyPathBlockObservers = [self mln_keyPathBlockObserversCreateIfNeeded:NO];
    for (NSMutableSet *observersForKeyPath in keyPathBlockObservers.allValues) {
        [observersForKeyPath makeObjectsPerformSelector:@selector(detach)];
        [observersForKeyPath removeAllObjects];
    }
    [keyPathBlockObservers removeAllObjects];
}

- (void)mln_removeObervationsForOwner:(id)owner keyPath:(NSString *)keyPath {
    NSMutableSet *observersForKeyPath = [self mln_keyPathBlockObserversCreateIfNeeded:NO][keyPath]
    ;
    
    NSMutableSet *observersForOwnerForKeyPath = [NSMutableSet set];
    for (MLNObserver *observer in observersForKeyPath) {
        if (observer.owner == owner) {
            [observersForOwnerForKeyPath addObject:observer];
        }
    }
    
    for (MLNObserver *observer in observersForOwnerForKeyPath) {
        [observer detach];
        [observersForKeyPath removeObject:observer];
    }
}
@end

#import "MLNArrayObserver.h"
@implementation NSObject (MLNArrayKVO)

- (void)mln_observeArray:(NSMutableArray *)array withBlock:(MLNBlockChange)observationBlock {
    MLNObserver *observer = nil;
    @autoreleasepool {
        observer = [array mln_observerForKeyPath:kArrayKVOPlaceHolder owner:self];
    }
    __weak __typeof(self)weakSelf = self;
    [observer addObservationBlock:^(id  _Nonnull observer, id  _Nonnull object, id  _Nonnull oldValue, id  _Nonnull newValue, NSDictionary<NSKeyValueChangeKey,id> * _Nonnull change) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        observationBlock(strongSelf, object, oldValue, newValue, change);
    }];
}

- (void)mln_removeArrayObervationsForOwner:(id)owner {
    [self mln_removeObervationsForOwner:owner keyPath:kArrayKVOPlaceHolder];
}

@end

@implementation NSObject (MLNDeprecated)
- (NSObject * _Nonnull (^)(NSString * _Nonnull, MLNKVOBlock _Nonnull))mln_subscribe {
    return self.mln_watch;
}
@end
