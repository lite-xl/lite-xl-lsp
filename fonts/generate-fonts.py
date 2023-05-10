#!/usr/bin/fontforge -script
#
# Generates a small LSP symbol icons font using 'Symbols Nerd Font'
#
# Usage:
# fontforge -script generate-font.py
#
# References:
# https://www.nerdfonts.com/font-downloads
# https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.0/NerdFontsSymbolsOnly.zip
#
import fontforge

# Define the path to the source font file
# Recommended font from the Symbols Nerd Font package is:
# Symbols-2048-em Nerd Font Complete Mono.ttf
src_font_path = "Symbols-2048-em Nerd Font Complete Mono.ttf"

# List of symbols to copy
# The symbol mappings were taken from:
# * https://github.com/onsails/lspkind.nvim
# * https://github.com/TorchedSammy/lite-xl-lspkind
symbols = [
    #
    # Nerdicons Preset
    #
    '', # 0xF77E Text
    '', # 0xF6A6 Method
    '', # 0xF794 Function
    '', # 0xF423 Constructor
    'ﰠ', # 0xFC20 Field
    '', # 0xF52A Variable
    'ﴯ', # 0xFD2F Class
    '', # 0xF0E8 Interface
    '', # 0xF487 Module
    'ﰠ', # 0xFC20 Property
    '塞', # 0xF96C Unit
    '', # 0xF89F Value
    '', # 0xF15D Enum
    '', # 0xF80A Keyword
    '', # 0xF44F Snippet
    '', # 0xF8D7 Color
    '', # 0xF718 File
    '', # 0xF706 Reference
    '', # 0xF74A Folder
    '', # 0xF15D EnumMember
    '', # 0xF8FE Constant
    'פּ', # 0xFB44 Struct
    '', # 0xF0E7 Event
    '', # 0xF694 Operator
    '', # 0xF128 Unknown
    '', # TypeParameter
    #
    # Codicons Preset
    #
    '', # Text
    '', # Method
    '', # Function
    '', # Constructor
    '', # Field
    '', # Variable
    '', # Class
    '', # Interface
    '', # Module
    '', # Property
    '', # Unit
    '', # Value
    '', # Enum
    '', # Keyword
    '', # Snippet
    '', # Color
    '', # File
    '', # Reference
    '', # Folder
    '', # EnumMember
    '', # Constant
    '', # Struct
    '', # Event
    '', # Operator
    '', # Unknown
    ''  # TypeParameter
]

# Convert symbols list to an integers list a.k.a. unicode values
unicode_values = []
for char in symbols:
    unicode_values.append(ord(char))

# Load the source font into FontForge
src_font = fontforge.open(src_font_path)

# Remove unwanted glyph
src_font.selection.select(*unicode_values)
src_font.selection.invert()
src_font.clear()

# Save as new font
src_font.fontname = "LSPSymbols"
src_font.familyname = "LSP Symbols"
src_font.fullname = "LSP Symbols"
src_font.generate("symbols.ttf")
