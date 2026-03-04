/// standardized operators, named based on function rather than syntax
pub const Operator = enum(u8) {
    Assign,
    Arrow,
    Path,
    MemberAccess,
    Range,
    RangeInc,
    NullUnwrap,

    Add,
    CompAdd,

    Sub,
    CompSub,

    Mul,
    CompMul,

    Div,
    CompDiv,

    Mod,
    CompMod,

    Lshift,
    CompLshift,

    Rshift,
    CompRshift,

    BitAnd,
    CompBitAnd,

    BitOr,
    CompBitOr,

    BitXor,
    CompBitXor,

    BitNot,
    CompBitNot,

    Not,
    Neq,
    Eq,
    Gt,
    Lt,
    Ge,
    Le,
    And,
    Or,
};