# Filling in a food from its nutrition label

When you add or edit a food (**Food › + Add food › + New food**), the
form has a **Fill in from a label** button at the top. It opens a screen
where you paste a nutrition label, as **JSON** or as plain text. As you
paste or type, the screen lists what it found under the box (name,
serving, every nutrient), so you can see whether it worked before
tapping **Fill in**. You can check and change everything again before
saving. The **ⓘ** button on that screen explains the steps below.

Ippo never goes online, so it cannot read a photo by itself. The quickest
way is:

1. Take a photo of the label.
2. Tap **Copy the format**. It copies instructions for the JSON format
   below, including the full list of nutrient names.
3. Send the photo and those instructions to an AI assistant (such as
   Claude). It replies with JSON.
4. Copy the answer, tap **Paste**, check what was found, tap **Fill in**.

Plain label text also works: copy it from a shop's website or a food
database, or type it.


## The JSON format

JSON is the main format: assistants write it reliably, and it uses the
same names as Ippo's data (`food_created` in `docs/data-format.md`), so
what you paste is exactly what gets saved, and the same JSON is easy to
make or check in Python.

```json
{
  "name": "Potato chips",
  "measured_in": "g",
  "per": "serving",
  "serving": {"unit": "chips", "count": 9, "amount": 28},
  "nutrients": {
    "energy_kcal": 150,
    "fat_g": 9,
    "saturated_fat_g": 1.5,
    "carbohydrates_g": 15,
    "sugars_g": 1,
    "fiber_g": 1,
    "proteins_g": 2,
    "sodium_mg": 170
  },
  "ingredients": "Potatoes, sunflower oil, salt."
}
```

| Name | Meaning |
| --- | --- |
| `name` | The food's name. |
| `measured_in` | `"g"` or `"ml"`. Anything else is taken as `"g"`. |
| `per` | `"serving"` if the values are per serving, `"100"` (or `"100 g"`, `"100 ml"`) if per 100. Per serving if left out. |
| `serving` | `count` pieces of `unit` weigh `amount` (in `measured_in` units), as in `food_created`. "2/3 cup (55 g)" is `{"unit": "cup", "count": 0.667, "amount": 55}`. Only a weight: `{"unit": "serving", "count": 1, "amount": 30}`. |
| `nutrients` | Nutrient field names (see "Nutrients" in `docs/data-format.md`), each ending in its unit, with plain numbers in that unit. `energy_kj` is turned into kcal if there is no `energy_kcal`; salt is worked out from `sodium_mg` if not given. |
| `nutrients_per_100` | Instead of `nutrients` and `per`: values per 100, as stored in a `food_created` event. So a food's event data can be pasted straight in. |
| `ingredients` | The ingredients, as on the label. |

Details:

- Text around the JSON, such as a sentence or a ```` ```json ```` block,
  is ignored: Ippo reads from the first `{` to the last `}`.
- Anything left out is simply not filled in. Nothing is guessed.
- Numbers written as text (`"9"`, `"1,5"`) are read; negative numbers
  and `null` are left out.
- Names Ippo does not know (a misspelled nutrient, a `brand`) are listed
  under the box as "Not used", so nothing is dropped silently.
- If the text is not JSON in this shape, it is read as label text
  (below).


## Pasting a whole meal

To log several foods at once, with new foods added to your list as you
go, use **Food › + Add food › Paste a meal**:

1. Take a photo of each food's nutrition label.
2. Tap **Copy the format** and send it to an AI assistant with the
   photos and how much you ate of each, such as "39 g ham, 76 g cheese,
   46 g crackers, 86 g cherries".
3. Copy the answer and tap **Paste**. The screen lists each food with
   the amount and its energy, marked **New in your foods** or **Already
   in your foods**, and anything it could not read, with the reason.
4. Check the day and time, and tap **Log**.

The JSON is a list of foods, each written as above plus `amount`: how
much was eaten, in its `measured_in` units. `time` (`"HH:MM"`) is
optional. A plain list of foods, without the object around it, also
works.

```json
{
  "time": "12:30",
  "foods": [
    {
      "name": "Potato chips",
      "measured_in": "g",
      "per": "serving",
      "serving": {"unit": "chips", "count": 9, "amount": 28},
      "nutrients": {"energy_kcal": 150, "fat_g": 9, "sodium_mg": 170},
      "amount": 46
    }
  ]
}
```

- A food whose name matches one already in your foods (ignoring
  capitals) is not added again: the entry uses that food and its own
  values, so a pasted label never silently changes a food you have.
- Each new food is saved as a normal food (`food_created`), and each
  amount as a normal entry (`food_entry_recorded`): the data looks
  exactly as if you had added them one by one.
- A food without a name, an amount, or energy, or with values per
  serving but no serving size, is not logged; the screen says which and
  why, and the others are still logged.


## Label text

Ippo reads the text line by line and ignores anything it does not
recognize. It understands:

- **US-style labels:** "Serving size 9 chips (28g)", "Calories 150",
  "Total Fat 9g", "Saturated Fat 1.5g", "Sodium 170mg", "Total
  Carbohydrate 15g", "Dietary Fiber 1g", "Total Sugars 1g",
  "Protein 2g".
- **European-style labels:** "per 100 g", "Energy 2010 kJ / 480 kcal",
  "Fat 30 g", "of which saturates 3 g", "Carbohydrate 50 g", "of which
  sugars 1 g", "Fibre 4 g", "Protein 6 g", "Salt 1.2 g".
- **Simple `name: value` lines:** `name: Potato chips`,
  `serving: 9 chips = 28 g`, `calories: 150`, `fat: 9 g`, and a line
  `per 100 g` if the values are per 100 g.

Details:

- If the text says "per 100 g" (or "per 100 ml"), the values are taken
  as per 100. Otherwise they are taken as per serving, and the serving
  size is needed to work out the values per 100.
- Energy in kJ only is turned into kcal (1 kcal = 4.184 kJ).
- Sodium is turned into salt (salt = sodium × 2.5) if no salt is given.
- Serving sizes can be fractions: "2/3 cup (55g)".
- Commas work as decimal marks: "3,5 g".
- Every nutrient on the label is kept, including trans fat,
  cholesterol, added sugars, minerals and vitamins. Amounts in mg, mcg
  or µg are turned into each nutrient's own unit. A line with only a %
  daily value ("Vitamin A 10%") is skipped: it gives no amount.
- **Ingredients**: everything after "Ingredients:" up to the next empty
  line is kept as the food's ingredients.


## Entering amounts in pieces

Once a food has a serving size, logging it offers a choice between its
pieces and grams: type **9 chips** and Ippo shows "That is 28 g." under
the field, and the calories; type **40 g** and it shows "That is about
12.9 chips". The entry always
stores the grams, plus the number of pieces if you typed pieces (see
`unit_count` in `docs/data-format.md`).
