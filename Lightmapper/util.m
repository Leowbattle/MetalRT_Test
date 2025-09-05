//
//  util.m
//  smallpt-metal
//
//  Created by Leo Battle on 26/08/2025.
//

#include <stdlib.h>

// I don't understand why but Swift's loop performance seems to be terrible.
// This basic function when implemented in Swift caused unnaceptable lag when resizing the window.
// The disassembly was full of references to iterators, optionals, and bounds checking (I'm pretty sure I compiled in release mode?)
// Even using UnsafeMutablePointer didn't improve performance.
void fill_random(unsigned int* ptr, int size) {
    for (int i = 0; i < size; i++) {
        ptr[i] = rand() % (1024 * 1024);
    }
}
