# Live: http://www.danvk.org/hex2dec.html

###*
# A function for converting hex <-> dec w/o loss of precision.
#
# The problem is that parseInt("0x12345...") isn't precise enough to convert
# 64-bit integers correctly.
#
# Internally, this uses arrays to encode decimal digits starting with the least
# significant:
# 8 = [8]
# 16 = [6, 1]
# 1024 = [4, 2, 0, 1]
###

# Adds two arrays for the given base (10 or 16), returning the result.
# This turns out to be the only "primitive" operation we need.

add = (x, y, base) ->
  z = []
  n = Math.max(x.length, y.length)
  carry = 0
  i = 0
  while i < n or carry
    xi = if i < x.length then x[i] else 0
    yi = if i < y.length then y[i] else 0
    zi = carry + xi + yi
    z.push zi % base
    carry = Math.floor(zi / base)
    i++
  z

# Returns a*x, where x is an array of decimal digits and a is an ordinary
# JavaScript number. base is the number base of the array x.

multiplyByNumber = (num, x, base) ->
  if num < 0
    return null
  if num == 0
    return []
  result = []
  power = x
  loop
    if num & 1
      result = add(result, power, base)
    num = num >> 1
    if num == 0
      break
    power = add(power, power, base)
  result

parseToDigitsArray = (str, base) ->
  digits = str.split('')
  ary = []
  i = digits.length - 1
  while i >= 0
    n = parseInt(digits[i], base)
    if isNaN(n)
      return null
    ary.push n
    i--
  ary

convertBase = (str, fromBase, toBase) ->
  `var i`
  digits = parseToDigitsArray(str, fromBase)
  if digits == null
    return null
  outArray = []
  power = [ 1 ]
  i = 0
  while i < digits.length
    # invariant: at this point, fromBase^i = power
    if digits[i]
      outArray = add(outArray, multiplyByNumber(digits[i], power, toBase), toBase)
    power = multiplyByNumber(fromBase, power, toBase)
    i++
  out = ''
  i = outArray.length - 1
  while i >= 0
    out += outArray[i].toString(toBase)
    i--
  out

decToHex = (decStr) ->
  hex = convertBase(decStr, 10, 16)
  if hex then '0x' + hex else null

hexToDec = (hexStr) ->
  if hexStr.substring(0, 2) == '0x'
    hexStr = hexStr.substring(2)
  hexStr = hexStr.toLowerCase()
  convertBase hexStr, 16, 10

module.exports=
  hex2dec:hexToDec
  dec2hex:decToHex
