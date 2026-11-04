//
//  ThirdPartyNoticesTests.swift
//  BChessTests
//
//  The notices the About screen shows: the file ships in the bundle and carries what the licenses require.
//

import Testing

struct ThirdPartyNoticesTests {

    @Test(arguments: [
        "Copyright © The author\n",
        "Colin M.L. Burnett", "Cburnett", "Pradyumna Kannan", "Sebastiano Vigna", "Tomasz Michniewski",
        // the BSD conditions of the pieces
        "1. Redistributions of source code must retain the above copyright notice",
        "2. Redistributions in binary form must reproduce the above copyright notice",
        "3. Neither the name of The author nor the names of its contributors",
        // the disclaimer, in upper case at both ends
        "THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS \"AS IS\"",
        "INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)",
        "EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.",
        // the app icon: the knight is derived from the same art, the veneers are CC0
        "The knight in the app icon is derived from the same Cburnett chess piece art",
        "okoume_veneer and teak_veneer", "Poly Haven", "CC0",
        // the conditions of magicmoves, whole
        "Copyright (C) 2007 Pradyumna Kannan.",
        "This code is provided 'as-is', without any expressed or implied warranty.",
        "it and redistribute it freely, subject to the following restrictions:",
        "claim that you wrote the original code. If you use this code in a\nproduct, an acknowledgment in the product documentation would be\nappreciated but is not required.",
        "misrepresented as being the original code.",
        "1. The origin of this code must not be misrepresented",
        "2. Altered source versions must be plainly marked as such",
        "3. This notice may not be removed or altered from any source distribution.",
    ])
    func noticesContain(_ fragment: String) {
        #expect(ThirdPartyNotices.text.contains(fragment))
    }

    @Test func noticesNameTheLaterContributors() {
        for name in ["Antonsusi", "TomFryers", "Apathor", "Cyco130", "Smasongarrison", "Edemaine"] {
            #expect(ThirdPartyNotices.text.contains(name))
        }
    }
}
