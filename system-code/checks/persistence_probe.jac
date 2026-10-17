# Isolated process-restart verification; not a production workspace service.
node FoundationProbe { has value: str; }

walker write_probe {
    can run with Root entry {
        if not [-->][?:FoundationProbe] {
            here ++> FoundationProbe(value="meridian-foundation");
        }
        commit();
        report "written";
    }
}

walker read_probe {
    can run with Root entry {
        records = [-->][?:FoundationProbe];
        assert len(records) == 1;
        assert records[0].value == "meridian-foundation";
        report "persistence verified";
    }
}
