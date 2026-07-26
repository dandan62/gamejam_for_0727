# Gunman Janken Combat

This context defines the language for player cards and their effects during a gunfight.

## Language

**Card Catalogue**:
The complete authoritative set of numbered player cards. Every representation of a card must agree with its catalogue entry.
_Avoid_: Existing card list, legacy cards

**Card ID**:
A unique number identifying exactly one entry in the **Card Catalogue**.
_Avoid_: File number, row number

**RSP Symbols**:
The ordered Rock, Scissors, and Paper symbols carried by a card. A card’s symbol count is independent of its action level, enchantment level, and rarity.
For Card IDs 59–61, the catalogue’s `RSP_num = 2` cells are source errors: the actual `R`, `S`, and `P` entries are authoritative, so each of these cards carries exactly one symbol.
_Avoid_: Enchantment strength, rarity count

**Combat**:
One encounter against one enemy. A Combat may contain multiple **Rounds**.
_Avoid_: Run, game

**Round**:
One ordered set of up to three **Bullet Fights**, beginning with bullet selection. The end of a Round is an effect boundary unless an effect explicitly lasts for the **Combat**.
_Avoid_: Combat, turn

**Bullet Fight**:
The resolution of one player bullet against the enemy bullet in the same slot.
_Avoid_: Round, combat

**Player Activation**:
The activation of a player bullet’s base action and enchantment after either a win or a tie in its **Bullet Fight**. A loss produces no player effect.
_Avoid_: Win-only activation

**Next Enemy Bullet**:
The enemy bullet in the immediately following slot of the same **Round**. The third slot has no Next Enemy Bullet.
_Avoid_: First bullet of the next Round

**Buff Enchantment (D)**:
An increase to player attack damage that lasts for the remainder of the current **Combat**. Each activation stacks additively without a cap; the complete stack resets when the Combat ends. It is the sole enchantment that persists across **Rounds**, and it does not increase guarding or healing.
_Avoid_: Run-long buff, round-only buff

**Charge Enchantment (B)**:
Bonus attack damage available only in the first **Bullet Fight** of a **Round** when the player bullet wins or ties. The bonus combines with base attack damage before enemy shield is applied and does not persist.
_Avoid_: Stored charge, next-attack charge

**Store Listing**:
One appearance of a card in a store inventory, with a price determined only by rarity. Its price remains fixed for that visit; a later Store Listing may receive a different price.
_Avoid_: Permanent card price

## Example dialogue

> **Developer:** “Card ID 12 differs from an older version. Which definition should we use?”
>
> **Domain expert:** “Use Card ID 12 from the Card Catalogue. Older definitions are not authoritative.”
>
> **Developer:** “Does a level-2 enchantment require two RSP Symbols?”
>
> **Domain expert:** “No. Enchantment level and symbol count are independent.”
>
> **Developer:** “A debuff activates in the third Bullet Fight. Does it affect the next Round?”
>
> **Domain expert:** “No. The third slot has no Next Enemy Bullet, so the debuff expires.”
>
> **Developer:** “Does Buff D disappear when the next Round begins?”
>
> **Domain expert:** “No. Buff D and its full accumulated stack last until the current Combat ends.”
>
> **Developer:** “Can Charge B bypass an enemy’s shield?”
>
> **Domain expert:** “No. Charge B becomes part of the attack’s ordinary damage before shield is applied.”
>
> **Developer:** “Does an enchantment activate when its Bullet Fight ties?”
>
> **Domain expert:** “Yes. A tie produces Player Activation just like a win.”
>
> **Developer:** “Must a card have the same price every time it appears?”
>
> **Domain expert:** “No. Each Store Listing receives its own rarity-based price.”
