<?php

class A {
    private $a = 100;
    public function sum($b) {
        return $this->a + $b;
    }
}


class B extends A {
}

$b = new B;
print $b->sum(10) . "\n";

