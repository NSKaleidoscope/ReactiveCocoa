//
//  RACStreamExamples.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACStreamExamples.h"

#import "RACStream.h"
#import "RACUnit.h"
#import "RACTuple.h"

NSString * const RACStreamExamples = @"RACStreamExamples";
NSString * const RACStreamExamplesClass = @"RACStreamExamplesClass";
NSString * const RACStreamExamplesInfiniteStream = @"RACStreamExamplesInfiniteStream";
NSString * const RACStreamExamplesVerifyValuesBlock = @"RACStreamExamplesVerifyValuesBlock";

SharedExampleGroupsBegin(RACStreamExamples)

sharedExamplesFor(RACStreamExamples, ^(NSDictionary *data) {
	Class streamClass = data[RACStreamExamplesClass];
	void (^verifyValues)(RACStream *, NSArray *) = data[RACStreamExamplesVerifyValuesBlock];
	RACStream *infiniteStream = data[RACStreamExamplesInfiniteStream];

	__block RACStream *(^streamWithValues)(NSArray *);
	
	before(^{
		streamWithValues = [^(NSArray *values) {
			RACStream *stream = [streamClass empty];

			for (id value in values) {
				stream = [stream concat:[streamClass return:value]];
			}

			return stream;
		} copy];
	});

	it(@"should return an empty stream", ^{
		RACStream *stream = [streamClass empty];
		verifyValues(stream, @[]);
	});

	it(@"should lift a value into a stream", ^{
		RACStream *stream = [streamClass return:RACUnit.defaultUnit];
		verifyValues(stream, @[ RACUnit.defaultUnit ]);
	});

	describe(@"-concat:", ^{
		it(@"should concatenate two streams", ^{
			RACStream *stream = [[streamClass return:@0] concat:[streamClass return:@1]];
			verifyValues(stream, @[ @0, @1 ]);
		});

		it(@"should concatenate three streams", ^{
			RACStream *stream = [[[streamClass return:@0] concat:[streamClass return:@1]] concat:[streamClass return:@2]];
			verifyValues(stream, @[ @0, @1, @2 ]);
		});

		it(@"should concatenate around an empty stream", ^{
			RACStream *stream = [[[streamClass return:@0] concat:[streamClass empty]] concat:[streamClass return:@2]];
			verifyValues(stream, @[ @0, @2 ]);
		});
	});

	it(@"should flatten", ^{
		RACStream *stream = [[streamClass return:[streamClass return:RACUnit.defaultUnit]] flatten];
		verifyValues(stream, @[ RACUnit.defaultUnit ]);
	});

	describe(@"-bind:", ^{
		it(@"should return the result of binding a single value", ^{
			RACStream *stream = [[streamClass return:@0] bind:^{
				return ^(NSNumber *value, BOOL *stop) {
					NSNumber *newValue = @(value.integerValue + 1);
					return [streamClass return:newValue];
				};
			}];

			verifyValues(stream, @[ @1 ]);
		});

		it(@"should concatenate the result of binding multiple values", ^{
			RACStream *baseStream = streamWithValues(@[ @0, @1 ]);
			RACStream *stream = [baseStream bind:^{
				return ^(NSNumber *value, BOOL *stop) {
					NSNumber *newValue = @(value.integerValue + 1);
					return [streamClass return:newValue];
				};
			}];

			verifyValues(stream, @[ @1, @2 ]);
		});

		it(@"should concatenate with an empty result from binding a value", ^{
			RACStream *baseStream = streamWithValues(@[ @0, @1, @2 ]);
			RACStream *stream = [baseStream bind:^{
				return ^(NSNumber *value, BOOL *stop) {
					if (value.integerValue == 1) return [streamClass empty];

					NSNumber *newValue = @(value.integerValue + 1);
					return [streamClass return:newValue];
				};
			}];

			verifyValues(stream, @[ @1, @3 ]);
		});

		it(@"should terminate immediately when returning nil", ^{
			RACStream *stream = [infiniteStream bind:^{
				return ^ id (id _, BOOL *stop) {
					return nil;
				};
			}];

			verifyValues(stream, @[]);
		});

		it(@"should terminate after one value when setting 'stop'", ^{
			RACStream *stream = [infiniteStream bind:^{
				return ^ id (id value, BOOL *stop) {
					*stop = YES;
					return [streamClass return:value];
				};
			}];

			verifyValues(stream, @[ RACUnit.defaultUnit ]);
		});

		it(@"should terminate immediately when returning nil and setting 'stop'", ^{
			RACStream *stream = [infiniteStream bind:^{
				return ^ id (id _, BOOL *stop) {
					*stop = YES;
					return nil;
				};
			}];

			verifyValues(stream, @[]);
		});

		it(@"should be restartable even with block state", ^{
			NSArray *values = @[ @0, @1, @2 ];
			RACStream *baseStream = streamWithValues(values);

			RACStream *countingStream = [baseStream bind:^{
				__block NSUInteger counter = 0;

				return ^(id x, BOOL *stop) {
					return [streamClass return:@(counter++)];
				};
			}];

			verifyValues(countingStream, @[ @0, @1, @2 ]);
			verifyValues(countingStream, @[ @0, @1, @2 ]);
		});

		it(@"should be interleavable even with block state", ^{
			NSArray *values = @[ @0, @1, @2 ];
			RACStream *baseStream = streamWithValues(values);

			RACStream *countingStream = [baseStream bind:^{
				__block NSUInteger counter = 0;

				return ^(id x, BOOL *stop) {
					return [streamClass return:@(counter++)];
				};
			}];

			// Just so +zip:reduce: thinks this is a unique stream.
			RACStream *anotherStream = [[streamClass empty] concat:countingStream];

			RACStream *zipped = [streamClass zip:@[ countingStream, anotherStream ] reduce:^(NSNumber *v1, NSNumber *v2) {
				return @(v1.integerValue + v2.integerValue);
			}];

			verifyValues(zipped, @[ @0, @2, @4 ]);
		});
	});

	describe(@"-flattenMap:", ^{
		it(@"should return a single mapped result", ^{
			RACStream *stream = [[streamClass return:@0] flattenMap:^(NSNumber *value) {
				NSNumber *newValue = @(value.integerValue + 1);
				return [streamClass return:newValue];
			}];

			verifyValues(stream, @[ @1 ]);
		});

		it(@"should concatenate the results of mapping multiple values", ^{
			RACStream *baseStream = streamWithValues(@[ @0, @1 ]);
			RACStream *stream = [baseStream flattenMap:^(NSNumber *value) {
				NSNumber *newValue = @(value.integerValue + 1);
				return [streamClass return:newValue];
			}];

			verifyValues(stream, @[ @1, @2 ]);
		});

		it(@"should concatenate with an empty result from mapping a value", ^{
			RACStream *baseStream = streamWithValues(@[ @0, @1, @2 ]);
			RACStream *stream = [baseStream flattenMap:^(NSNumber *value) {
				if (value.integerValue == 1) return [streamClass empty];

				NSNumber *newValue = @(value.integerValue + 1);
				return [streamClass return:newValue];
			}];

			verifyValues(stream, @[ @1, @3 ]);
		});
	});

	describe(@"-sequenceMany:", ^{
		it(@"should return the result of sequencing a single value", ^{
			RACStream *stream = [[streamClass return:@0] sequenceMany:^{
				return [streamClass return:@10];
			}];

			verifyValues(stream, @[ @10 ]);
		});

		it(@"should concatenate the result of sequencing multiple values", ^{
			RACStream *baseStream = streamWithValues(@[ @0, @1 ]);

			__block NSUInteger value = 10;
			RACStream *stream = [baseStream sequenceMany:^{
				return [streamClass return:@(value++)];
			}];

			verifyValues(stream, @[ @10, @11 ]);
		});
	});

	it(@"should map", ^{
		RACStream *baseStream = streamWithValues(@[ @0, @1, @2 ]);
		RACStream *stream = [baseStream map:^(NSNumber *value) {
			return @(value.integerValue + 1);
		}];

		verifyValues(stream, @[ @1, @2, @3 ]);
	});

	it(@"should map and replace", ^{
		RACStream *baseStream = streamWithValues(@[ @0, @1, @2 ]);
		RACStream *stream = [baseStream mapReplace:RACUnit.defaultUnit];

		verifyValues(stream, @[ RACUnit.defaultUnit, RACUnit.defaultUnit, RACUnit.defaultUnit ]);
	});

	it(@"should filter", ^{
		RACStream *baseStream = streamWithValues(@[ @0, @1, @2, @3, @4, @5, @6 ]);
		RACStream *stream = [baseStream filter:^ BOOL (NSNumber *value) {
			return value.integerValue % 2 == 0;
		}];

		verifyValues(stream, @[ @0, @2, @4, @6 ]);
	});

	it(@"should start with a value", ^{
		RACStream *stream = [[streamClass return:@1] startWith:@0];
		verifyValues(stream, @[ @0, @1 ]);
	});

	describe(@"-skip:", ^{
		__block NSArray *values;
		__block RACStream *stream;

		before(^{
			values = @[ @0, @1, @2 ];
			stream = streamWithValues(values);
		});

		it(@"should skip any valid number of values", ^{
			for (NSUInteger i = 0; i < values.count; i++) {
				verifyValues([stream skip:i], [values subarrayWithRange:NSMakeRange(i, values.count - i)]);
			}
		});

		it(@"should return an empty stream when skipping too many values", ^{
			verifyValues([stream skip:4], @[]);
		});
	});

	describe(@"-take:", ^{
		describe(@"with three values", ^{
			__block NSArray *values;
			__block RACStream *stream;

			before(^{
				values = @[ @0, @1, @2 ];
				stream = streamWithValues(values);
			});

			it(@"should take any valid number of values", ^{
				for (NSUInteger i = 0; i < values.count; i++) {
					verifyValues([stream take:i], [values subarrayWithRange:NSMakeRange(0, i)]);
				}
			});

			it(@"should return the same stream when taking too many values", ^{
				verifyValues([stream take:4], values);
			});
		});

		it(@"should take and terminate from an infinite stream", ^{
			verifyValues([infiniteStream take:0], @[]);
			verifyValues([infiniteStream take:1], @[ RACUnit.defaultUnit ]);
			verifyValues([infiniteStream take:2], @[ RACUnit.defaultUnit, RACUnit.defaultUnit ]);
		});

		it(@"should take and terminate from a single-item stream", ^{
			NSArray *values = @[ RACUnit.defaultUnit ];
			RACStream *stream = streamWithValues(values);
			verifyValues([stream take:1], values);
		});
	});
  
	describe(@"zip stream creation methods", ^{
		__block NSArray *threeStreams;
		__block NSArray *threeTuples;
		__block RACStream *streamOne;
		__block RACStream *streamTwo;
		__block RACStream *streamThree;
		
		before(^{
			NSArray *valuesOne = @[ @"Ada", @"Bob", @"Dea" ];
			NSArray *valuesTwo = @[ @"eats", @"cooks", @"jumps" ];
			NSArray *valuesThree = @[ @"fish", @"bear", @"rock" ];
			streamOne = streamWithValues(valuesOne);
			streamTwo = streamWithValues(valuesTwo);
			streamThree = streamWithValues(valuesThree);
			threeStreams = @[ streamOne, streamTwo, streamThree ];
			RACTuple *tupleOne = [RACTuple tupleWithObjectsFromArray:@[ valuesOne[0], valuesTwo[0], valuesThree[0] ]];
			RACTuple *tupleTwo = [RACTuple tupleWithObjectsFromArray:@[ valuesOne[1], valuesTwo[1], valuesThree[1] ]];
			RACTuple *tupleThree = [RACTuple tupleWithObjectsFromArray:@[ valuesOne[2], valuesTwo[2], valuesThree[2] ]];
			threeTuples = @[ tupleOne, tupleTwo, tupleThree ];
		});
		
		describe(@"+zip:reduce:", ^{
			it(@"should reduce values if a block is given", ^{
				RACStream *stream = [streamClass zip:threeStreams reduce:^ NSString * (id x, id y, id z) {
					return [NSString stringWithFormat:@"%@ %@ %@", x, y, z];
				}];
				verifyValues(stream, @[ @"Ada eats fish", @"Bob cooks bear", @"Dea jumps rock" ]);
			});
			
			it(@"should make a stream of tuples if no block is given", ^{
				RACStream *stream = [streamClass zip:threeStreams reduce:nil];
				verifyValues(stream, threeTuples);
			});
			
			it(@"should truncate streams", ^{
				RACStream *shortStream = streamWithValues(@[ @"now", @"later" ]);
				NSArray *streams = [threeStreams arrayByAddingObject:shortStream];
				RACStream *stream = [streamClass zip:streams reduce:^ NSString * (id w, id x, id y, id z) {
					return [NSString stringWithFormat:@"%@ %@ %@ %@", w, x, y, z];
				}];
				verifyValues(stream, @[ @"Ada eats fish now", @"Bob cooks bear later" ]);
			});
			
			it(@"should work on infinite streams", ^{
				NSArray *streams = [threeStreams arrayByAddingObject:infiniteStream];
				RACStream *stream = [streamClass zip:streams reduce:^ NSString * (id w, id x, id y, id z) {
					return [NSString stringWithFormat:@"%@ %@ %@", w, x, y];
				}];
				verifyValues(stream, @[ @"Ada eats fish", @"Bob cooks bear", @"Dea jumps rock" ]);
			});
			
			it(@"should handle multiples of the same stream", ^{
				NSArray *streams = @[ streamOne, streamOne, streamTwo, streamThree, streamTwo, streamThree ];
				RACStream *stream = [streamClass zip:streams reduce:^ NSString * (id x1, id x2, id y1, id z1, id y2, id z2) {
					return [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@", x1, x2, y1, z1, y2, z2];
				}];
				verifyValues(stream, @[ @"Ada Ada eats fish eats fish", @"Bob Bob cooks bear cooks bear", @"Dea Dea jumps rock jumps rock" ]);
			});
		});
		
		describe(@"+zip:", ^{
			it(@"should make a stream of tuples out of an array of streams", ^{
				RACStream *stream = [streamClass zip:threeStreams];
				verifyValues(stream, threeTuples);
			});

			it(@"should make an empty stream if given an empty array", ^{
				RACStream *stream = [streamClass zip:@[]];
				verifyValues(stream, @[]);
			});
			
			it(@"should make a stream of tuples out of an enumerator of streams", ^{
				RACStream *stream = [streamClass zip:threeStreams.objectEnumerator];
				verifyValues(stream, threeTuples);
			});
			
			it(@"should make an empty stream if given an empty enumerator", ^{
				RACStream *stream = [streamClass zip:@[].objectEnumerator];
				verifyValues(stream, @[]);
			});
		});
	});

	describe(@"+concat:", ^{
		__block NSArray *streams = nil;
		__block NSArray *result = nil;
		
		before(^{
			RACStream *a = [streamClass return:@0];
			RACStream *b = [streamClass empty];
			RACStream *c = streamWithValues(@[ @1, @2, @3 ]);
			RACStream *d = [streamClass return:@4];
			RACStream *e = [streamClass return:@5];
			RACStream *f = [streamClass empty];
			RACStream *g = [streamClass empty];
			RACStream *h = streamWithValues(@[ @6, @7 ]);
			streams = @[ a, b, c, d, e, f, g, h ];
			result = @[ @0, @1, @2, @3, @4, @5, @6, @7 ];
		});
		
		it(@"should concatenate an array of streams", ^{
			RACStream *stream = [streamClass concat:streams];
			verifyValues(stream, result);
		});
		
		it(@"should concatenate an enumerator of streams", ^{
			RACStream *stream = [streamClass concat:streams.objectEnumerator];
			verifyValues(stream, result);
		});
	});

	it(@"should scan", ^{
		RACStream *stream = streamWithValues(@[ @1, @2, @3, @4 ]);
		RACStream *scanned = [stream scanWithStart:@0 combine:^(NSNumber *running, NSNumber *next) {
			return @(running.integerValue + next.integerValue);
		}];

		verifyValues(scanned, @[ @1, @3, @6, @10 ]);
	});

	describe(@"taking with a predicate", ^{
		NSArray *values = @[ @0, @1, @2, @3, @0, @2, @4 ];

		__block RACStream *stream;

		before(^{
			stream = streamWithValues(values);
		});

		it(@"should take until a predicate is true", ^{
			RACStream *taken = [stream takeUntilBlock:^ BOOL (NSNumber *x) {
				return x.integerValue >= 3;
			}];

			verifyValues(taken, @[ @0, @1, @2 ]);
		});

		it(@"should take while a predicate is true", ^{
			RACStream *taken = [stream takeWhileBlock:^ BOOL (NSNumber *x) {
				return x.integerValue <= 1;
			}];

			verifyValues(taken, @[ @0, @1 ]);
		});

		it(@"should take a full stream", ^{
			RACStream *taken = [stream takeWhileBlock:^ BOOL (NSNumber *x) {
				return x.integerValue <= 10;
			}];

			verifyValues(taken, values);
		});

		it(@"should return an empty stream", ^{
			RACStream *taken = [stream takeWhileBlock:^ BOOL (NSNumber *x) {
				return x.integerValue < 0;
			}];

			verifyValues(taken, @[]);
		});

		it(@"should terminate an infinite stream", ^{
			RACStream *infiniteCounter = [infiniteStream scanWithStart:@0 combine:^(NSNumber *running, id _) {
				return @(running.unsignedIntegerValue + 1);
			}];

			RACStream *taken = [infiniteCounter takeWhileBlock:^ BOOL (NSNumber *x) {
				return x.integerValue <= 5;
			}];

			verifyValues(taken, @[ @1, @2, @3, @4, @5 ]);
		});
	});

	describe(@"skipping with a predicate", ^{
		NSArray *values = @[ @0, @1, @2, @3, @0, @2, @4 ];

		__block RACStream *stream;

		before(^{
			stream = streamWithValues(values);
		});

		it(@"should skip until a predicate is true", ^{
			RACStream *taken = [stream skipUntilBlock:^ BOOL (NSNumber *x) {
				return x.integerValue >= 3;
			}];

			verifyValues(taken, @[ @3, @0, @2, @4 ]);
		});

		it(@"should skip while a predicate is true", ^{
			RACStream *taken = [stream skipWhileBlock:^ BOOL (NSNumber *x) {
				return x.integerValue <= 1;
			}];

			verifyValues(taken, @[ @2, @3, @0, @2, @4 ]);
		});

		it(@"should skip a full stream", ^{
			RACStream *taken = [stream skipWhileBlock:^ BOOL (NSNumber *x) {
				return x.integerValue <= 10;
			}];

			verifyValues(taken, @[]);
		});

		it(@"should finish skipping immediately", ^{
			RACStream *taken = [stream skipWhileBlock:^ BOOL (NSNumber *x) {
				return x.integerValue < 0;
			}];

			verifyValues(taken, values);
		});
	});

	describe(@"-mapPreviousWithStart:combine:", ^{
		NSArray *values = @[ @1, @2, @3 ];
		__block RACStream *stream;
		beforeEach(^{
			stream = streamWithValues(values);
		});

		it(@"should pass the previous next into the combine block", ^{
			NSMutableArray *previouses = [NSMutableArray array];
			RACStream *mapped = [stream mapPreviousWithStart:nil combine:^(id previous, id next) {
				[previouses addObject:previous ?: RACTupleNil.tupleNil];
				return next;
			}];

			verifyValues(mapped, @[ @1, @2, @3 ]);

			NSArray *expected = @[ RACTupleNil.tupleNil, @1, @2 ];
			expect(previouses).to.equal(expected);
		});

		it(@"should send the combined value", ^{
			RACStream *mapped = [stream mapPreviousWithStart:@1 combine:^(NSNumber *previous, NSNumber *next) {
				return [NSString stringWithFormat:@"%lu - %lu", (unsigned long)previous.unsignedIntegerValue, (unsigned long)next.unsignedIntegerValue];
			}];

			verifyValues(mapped, @[ @"1 - 1", @"1 - 2", @"2 - 3" ]);
		});
	});
});

SharedExampleGroupsEnd